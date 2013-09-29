require 'socket'
require 'io/wait'
require 'digest/md5'

LI_DIRECTION_OUTPUT = 0x20
LI_CMD_RECEIVE_DATA = 0x04
TELECOMMAND_KEY = "32_BYTESFORAVERYSECURESECRETKEY" + 0.chr
CALLSIGN = "012345"
PORT = 10000
AX25_HEADER = CALLSIGN + (0x01).chr + CALLSIGN + [0x01,0x03,0xF0].map(&:chr).join

sem = Mutex.new
received_data = []

def compute_mac(data,seq_nr,key)
	digest = Digest::MD5.new
	digest << key
	
	digest << (seq_nr.to_i & 0xFF).chr + ((seq_nr.to_i >> 8) & 0xFF).chr +
		((seq_nr.to_i >> 16) & 0xFF).chr + ((seq_nr.to_i >> 24) & 0xFF).chr
	
	digest << data
	
	digest.digest[2] + digest.digest[1] + digest.digest[0] 
	
end

def fletcher_checksum16(data,count,accum)
	sum1 = accum >> 8
	sum2 = accum & 0xFF
	
	(0..count-1).each do |i|
		sum1 = (sum1 + data[i].ord) % 256
		sum2 = (sum2 + sum1) % 256
	end
	
	sum1 << 8 | sum2
end

def build_packet(seq_nr, command)
	
	seq_buf =((seq_nr.to_i >> 16) & 0xFF).chr + ((seq_nr.to_i >> 8) & 0xFF).chr +   (seq_nr.to_i & 0xFF).chr

	app_payload = compute_mac(command,seq_nr,TELECOMMAND_KEY) + seq_buf + command
	#p "Payload:"
	#p app_payload.split('').map(&:ord).map{|e| e.to_s(16)}

	ax25_packet = AX25_HEADER + app_payload + "aaaa" # aaaa is a fake CRC
	#p "AX25:"
	#p ax25_packet.split('').map(&:ord).map{|e| e.to_s(16)}
	p_size = ax25_packet.length
	li_header = [LI_DIRECTION_OUTPUT,LI_CMD_RECEIVE_DATA,p_size >> 8, p_size & 0xFF].map(&:chr).join
	chksum1 = fletcher_checksum16(li_header,li_header.length,0)
	chksum1_str = [chksum1 >> 8, chksum1 & 0xFF].map(&:chr).join
	
	chksum2 = fletcher_checksum16(chksum1_str,2,chksum1)
	chksum2 = fletcher_checksum16(ax25_packet,p_size,chksum2)
	
	chksum2_str = [chksum2 >> 8, chksum2 & 0xFF].map(&:chr).join
	
	"He" + li_header + chksum1_str + ax25_packet + chksum2_str
end

@server = TCPServer.new PORT

def wait_for_manolito
	STDOUT.puts 'Manolito is not online.'
	STDOUT.puts 'Waiting for Manolito...'
	@manolito = @server.accept
	STDOUT.puts 'Manolito connected!'
end

wait_for_manolito

s = STDOUT

t = Thread.new do
	while(1) do
		sem.synchronize {
			if @manolito.closed?
				wait_for_manolito
			end
			while @manolito.ready? do
				received_data << @manolito.getc
			end
		}
		if !received_data.empty?
			s.print "\r\n"
			s.puts "manolito (ascii)>" + received_data.map(&:to_s).join
			s.puts "manolito (hex)  > " + received_data.map{|c| c.ord.to_s(16)}.join(' ')
			s.print "ground control  > "
			received_data = []
		end
		sleep 0.001
	end
end

seq_nr = 0
while(1) do
	
	print 'ground control  > '
	message = gets.strip
	
	
	if message == 'exit'
		exit
	end
	
	puts 'Sending'

	seq_nr += 1
	command = message.split(' ').map{|c| c.to_i(16)}.map(&:chr).join
	packet = build_packet(seq_nr, command)
	
	sem.synchronize {
		@manolito.send(packet,0) rescue wait_for_manolito
	}
end
t.join
