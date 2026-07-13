abstract type Instrument end

mutable struct GenericInstrument <: Instrument
	handle::ViObject
	connected::Bool
	bufSize::UInt32
end
GenericInstrument() = GenericInstrument(0, false, 1024)

function connect!(rm, instr::Instrument, address::AbstractString)
	if !instr.connected
		instr.handle = viOpen(rm, address)
		instr.connected = true
	end
end

function disconnect!(instr::Instrument)
	if instr.connected
		viClose(instr.handle)
		instr.connected = false
	end
end

#String reads and writes
check_connected(instr::Instrument) = @assert instr.connected "Instrument is not connected!"

macro check_connected(ex)
	funcproto = ex.args[1]
	body = ex.args[2]
	instrument_obj = funcproto.args[2]
	checkbody = quote
		check_connected($(instrument_obj))
		$body
	end
	return Expr(:function, esc(funcproto), esc(checkbody))
end

@check_connected write(instr::Instrument, msg::AbstractString) = viWrite(instr.handle, msg)

@check_connected read(instr::Instrument) = rstrip(viRead(instr.handle; bufSize=instr.bufSize), ['\r', '\n'])

@check_connected readavailable(instr::Instrument) = readavailable(instr.handle)

@check_connected statusbyte(instr::Instrument) = viReadSTB(instr.handle)

@check_connected clear(instr::Instrument) = viClear(instr.handle)

import Base: flush
@check_connected function Base.flush(instr::Instrument, mode=:read_discard)
	modebyte::ViUInt16 = 0
	if mode === :read
		modebyte = VI_VI_READ_BUF
	elseif mode === :write
		modebyte = VI_WRITE_BUF
	elseif mode === :read_discard
		modebyte = VI_READ_BUF_DISCARD
	elseif mode === :write_discard
		modebyte = VI_WRITE_BUF_DISCARD
	else
		throw(ArgumentError("`mode` must be one of :read, :write, :read_discard, or :write_discard"))
	end
	viFlush(instr.handle, modebyte)
end

function query(instr::Instrument, msg::AbstractString; delay::Real=0)
	write(instr, msg)
	sleep(delay)
	read(instr)
end
