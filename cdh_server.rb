require 'socket'
require 'io/wait'
require 'digest/md5'

LI_DIRECTION_OUTPUT = 0x20
LI_CMD_RECEIVE_DATA = 0x04

sem = Mutex.new

received_data = []

telecommand_key = "32_BYTESFORAVERYSECURESECRETKEY" + 0.chr
callsign = "012345"

def compute_mac(data,seq_nr,key)
	digest = Digest::MD5.new
	digest << key
	
	digest << (seq_nr.to_i & 0xFF).chr + ((seq_nr.to_i >> 8) & 0xFF).chr + ((seq_nr.to_i >> 16) & 0xFF).chr + ((seq_nr.to_i >> 24) & 0xFF).chr
	
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

@server = TCPServer.new 10000

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
			s.puts "manolito (ascii)>" + received_data.map(&:to_s).join
			s.puts "manolito (hex)  > " + received_data.map{|c| c.ord.to_s(16)}.join(' ')
			s.puts "ground control  > "
			received_data = []
		end
		sleep 0.001
	end
end

seq_nr = 0
while(1) do
	
	puts 'ground control  > '
	message = gets
	puts 'Sending'

	seq_nr += 1
	seq_buf =((seq_nr.to_i >> 16) & 0xFF).chr + ((seq_nr.to_i >> 8) & 0xFF).chr +   (seq_nr.to_i & 0xFF).chr
	
	
	command = message.split(' ').map{|c| c.to_i(16)}.map(&:chr).join # SS_PLATFORM CMD_SOFT_RESET

	app_payload = compute_mac(command,seq_nr,telecommand_key) + seq_buf + command
	#p "Payload:"
	#p app_payload.split('').map(&:ord).map{|e| e.to_s(16)}

	ax25_packet = callsign + (0x01).chr + callsign + [0x01,0x03,0xF0].map(&:chr).join + app_payload + "aaaa" # aaaa is a fake CRC
	#p "AX25:"
	#p ax25_packet.split('').map(&:ord).map{|e| e.to_s(16)}
	p_size = ax25_packet.length
	li_header = [LI_DIRECTION_OUTPUT,LI_CMD_RECEIVE_DATA,p_size >> 8, p_size & 0xFF].map(&:chr).join
	chksum1 = fletcher_checksum16(li_header,li_header.length,0)
	chksum1_str = [chksum1 >> 8, chksum1 & 0xFF].map(&:chr).join
	
	chksum2 = fletcher_checksum16(chksum1_str,2,chksum1)
	chksum2 = fletcher_checksum16(ax25_packet,p_size,chksum2)
	
	chksum2_str = [chksum2 >> 8, chksum2 & 0xFF].map(&:chr).join
	
	li_packet = "He" + li_header + chksum1_str + ax25_packet + chksum2_str
	
	#p "Packet:"
	#p li_packet.split('').map(&:ord).map{|e| e.to_s(16)}
	
	
	
	
	
	while(sem.synchronize{@manolito.closed?}) do
		sleep 0.01
	end
	@manolito.send li_packet,0 rescue wait_for_manolito
	#p 'Sent'

end
#t2 = Thread.new do
#	while(1) do
#		if STDIN.ready?
#			manolito.putc STDIN.getc
#		end
#	end
#	sleep 10
#end

t.join
#t2.join
