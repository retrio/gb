package strafe.emu.gb;

import haxe.ds.Vector;


@:build(strafe.macro.Optimizer.build())
class CPU
{
	public var cart:Cart;
	public var video:Video;

	public var cycleCount:Int = 0;
	public var cycles:Int = 0;

	var ticks:Int = 0;

#if cputrace
	var log:String;
#end

	var a:Int = 0x01;
	var b:Int = 0x00;
	var c:Int = 0x13;
	var d:Int = 0x00;
	var e:Int = 0xd8;
	var h:Int = 0x01;
	var l:Int = 0x4d;

	var sp:Int = 0xfffe;
	var pc:Int = 0x100;

	var cf:Bool = true;		// carry flag
	var hf:Bool = true;		// half carry flag
	var sf:Bool = false;	// subtract flag
	var zf:Bool = true;		// zero flag

	var f(get, set):Int;
	inline function get_f() return (zf ? 0x80 : 0) | (sf ? 0x40 : 0) | (hf ? 0x20 : 0) | (cf ? 0x10 : 0);
	inline function set_f(byte:Int)
	{
		cf = Util.getbit(byte, 4);
		hf = Util.getbit(byte, 5);
		sf = Util.getbit(byte, 6);
		zf = Util.getbit(byte, 7);
		return byte;
	}

	var bc(get, set):Int;
	inline function get_bc() return (b << 8) | c;
	inline function set_bc(byte:Int)
	{
		b = (byte & 0xff00) >> 8;
		c = byte & 0xff;
		return byte;
	}
	var de(get, set):Int;
	inline function get_de() return (d << 8) | e;
	inline function set_de(byte:Int)
	{
		d = (byte & 0xff00) >> 8;
		e = byte & 0xff;
		return byte;
	}
	var hl(get, set):Int;
	inline function get_hl() return (h << 8) | l;
	inline function set_hl(byte:Int)
	{
		h = (byte & 0xff00) >> 8;
		l = byte & 0xff;
		return byte;
	}
	var af(get, set):Int;
	inline function get_af() return (a << 8) | f;
	inline function set_af(byte:Int)
	{
		a = (byte & 0xff00) >> 8;
		f = byte & 0xff;
		return byte;
	}

	var ime:Bool = true;					// interrupt master enable
	var interruptsRequested:Vector<Bool>;
	var interruptsEnabled:Vector<Bool>;

	public var interruptsEnabledFlag(get, set):Int;
	inline function get_interruptsEnabledFlag()
	{
		return (interruptsEnabled[0] ? 0x1 : 0) |
			(interruptsEnabled[1] ? 0x2 : 0) |
			(interruptsEnabled[2] ? 0x4 : 0) |
			(interruptsEnabled[3] ? 0x8 : 0) |
			(interruptsEnabled[4] ? 0x10 : 0);
	}
	inline function set_interruptsEnabledFlag(v:Int)
	{
		@unroll for (i in 0 ... 5) interruptsEnabled[i] = Util.getbit(v, i);
		return v;
	}

	public function new()
	{
		interruptsEnabled = new Vector(5);
		for (i in 0 ... interruptsEnabled.length) interruptsEnabled[i] = false;
		interruptsRequested = new Vector(5);
		for (i in 0 ... interruptsRequested.length) interruptsRequested[i] = false;
		interruptsRequested[Interrupt.Vblank] = true;
	}

	public function init(cart:Cart, video:Video)
	{
		this.cart = cart;
		cart.cpu = this;
		this.video = video;
	}

	public function irq(interruptType:Interrupt)
	{
		interruptsRequested[interruptType] = true;
	}

	public function runFrame()
	{
		video.stolenCycles = 0;
		while (!video.finished)
		{
			runCycle();

			var projScanline = video.scanline + ((video.cycles + cycles) / 456);
			if (projScanline > video.scanline)
			{
				video.catchUp();
			}
		}
		video.finished = false;
	}

	inline function runCycle()
	{
#if cputrace
		log = StringTools.hex(cycleCount, 8).toLowerCase();
		log += " L" + StringTools.hex(video.scanline, 2).toLowerCase();
		log += " PC:" + StringTools.hex(pc, 4).toLowerCase();
#end
		var op = readpc();
#if cputrace
		log += " OP:" + StringTools.hex(op, 2).toLowerCase();
		log += " AF:" + StringTools.hex(af, 4).toLowerCase();
		log += " BC:" + StringTools.hex(bc, 4).toLowerCase();
		log += " DE:" + StringTools.hex(de, 4).toLowerCase();
		log += " HL:" + StringTools.hex(hl, 4).toLowerCase();
		log += " SP:" + StringTools.hex(sp, 4).toLowerCase();
#end

		runOp(op);

		if (ime)
		{
			var interrupted = false;
			@unroll for (i in 0 ... 5)
			{
				if (!interrupted && interruptsEnabled[i] && interruptsRequested[i])
				{
					interrupt(i);
					interrupted = true;
				}
			}
		}

		cycleCount += ticks;
		cycles += ticks;

#if cputrace
#if sys
		Sys.println(log);
#else
		trace(log);
#end
#end
	}

	inline function runOp(op:Int)
	{
		ticks = tickValues[op];

		switch (op)
		{
			case 0x00:	// NOP
			case 0x01:	// LD BC,nn
				bc = read16pc();
			case 0x02:	// LD (BC),A
				write(bc, a);
			case 0x03:	// INC BC
				bc++;
			case 0x04:	// INC B
				b = inc(b);
			case 0x05:	// DEC B
				b = dec(b);
			case 0x06:	// LD B,n
				b = readpc();
			case 0x07:	// RLCA
				cf = a > 0x7f;
				a = (a << 1 & 0xff) | (a >> 7);
				zf = sf = hf = false;
			case 0x08:	// LD (nn),SP
				write16(read16pc(), sp);
			case 0x09:	// ADD HL,BC
				hl = add16(hl, bc);
			case 0x0a:	// LD A,(BC)
				a = read(bc);
			case 0x0b:	// DEC BC
				bc--;
			case 0x0c:	// INC C
				c = inc(c);
			case 0x0d:	// DEC C
				c = dec(c);
			case 0x0e:	// LD C,n
				c = readpc();
			case 0x0f:	// RRCA
				a = (a >> 1) | ((a & 1) << 7);
				cf = a > 0x7f;
				zf = sf = hf = false;
			case 0x10:	// STOP
				// TODO
				throw "NYI " + StringTools.hex(op, 2);
			case 0x11:	// LD DE,nn
				de = read16pc();
			case 0x12:	// LD (DE),A
				write(de, a);
			case 0x13:	// INC DE
				de++;
			case 0x14:	// INC D
				d = inc(d);
			case 0x15:	// DEC D
				d = dec(d);
			case 0x16:	// LD D,n
				d = readpc();
			case 0x17:	// RLA
				var carry = cf ? 1 : 0;
				cf = a > 0x7f;
				a = ((a << 1) & 0xff) | carry;
				zf = sf = hf = false;
			case 0x18:	// JR n
				var inc = signed(readpc());
				pc += inc;
			case 0x19:	// ADD HL,DE
				hl = add16(hl, de);
			case 0x1a:	// LD A,(DE)
				a = read(de);
			case 0x1b:	// DEC DE
				de--;
			case 0x1c:	// INC E
				e = inc(e);
			case 0x1d:	// DEC E
				e = dec(e);
			case 0x1e:	// LD E,n
				e = readpc();
			case 0x1f:	// RRA
				var carry = cf ? 0x80 : 0;
				cf = Util.getbit(a, 0);
				a = (a >> 1) | carry;
				zf = sf = hf = false;
			case 0x20:	// JR NZ,n
				if (!zf)
				{
					var inc = signed(readpc());
					pc += inc;
					ticks += 4;
				}
				else ++pc;
			case 0x21:	// LD HL,nn
				hl = read16pc();
			case 0x22:	// LDI (HL),A
				write(hl++, a);
			case 0x23:	// INC HL
				hl++;
			case 0x24:	// INC H
				h = inc(h);
			case 0x25:	// DEC H
				h = dec(h);
			case 0x26:	// LD H,n
				h = readpc();
			case 0x27:	// DAA
				var tmp:Int = cf ? 0x60 : 0;

				if (hf) tmp |= 0x06;
				if (!sf)
				{
					if (a & 0xf > 0x9)
						tmp |= 0x06;
					if (a > 0x99)
						tmp |= 0x60;
					a += tmp;
					cf = tmp > 0x5f;
				} else a -= tmp;

				a &= 0xff;

				zf = a == 0;
				hf = false;

			case 0x28:	// JR Z,n
				if (zf)
				{
					var inc = signed(readpc());
					pc += inc;
					ticks += 4;
				}
				else ++pc;
			case 0x29:	// ADD HL,HL
				hl = add16(hl, hl);
			case 0x2a:	// LDI A,(HL)
				a = read(hl++);
			case 0x2b:	// DEC HL
				hl--;
			case 0x2c:	// INC L
				l = inc(l);
			case 0x2d:	// DEC L
				l = dec(l);
			case 0x2e:	// LD L,n
				l = readpc();
			case 0x2f:	// CPL
				a ^= 0xff;
				sf = hf = true;
			case 0x30:	// JR NC,n
				if (!cf)
				{
					var inc = signed(readpc());
					pc += inc;
					ticks += 4;
				}
				else ++pc;
			case 0x31:	// LD SP,nn
				sp = read16pc();
			case 0x32:	// LDD (HL),A
				write(hl--, a);
			case 0x33:	// INC SP
				sp = (sp + 1) & 0xffff;
			case 0x34:	// INC (HL)
				var tmp = (read(hl) + 1) & 0xff;
				zf = tmp == 0;
				hf = (tmp & 0xf) == 0;
				sf = false;
				write(hl, tmp);
			case 0x35:	// DEC (HL)
				var tmp = (read(hl) - 1) & 0xff;
				zf = tmp == 0;
				hf = (tmp & 0xf) == 0xf;
				sf = true;
				write(hl, tmp);
			case 0x36:	// LD (HL),n
				write(hl, readpc());
			case 0x37:	// SCF
				cf = true;
				sf = hf = false;
			case 0x38:	// JR C,n
				if (cf)
				{
					var inc = signed(readpc());
					pc += inc;
					ticks += 4;
				}
				else ++pc;
			case 0x39:	// ADD HL,SP
				hl = add16(hl, sp);
			case 0x3a:	// LDD A,(HL)
				a = read(hl--);
			case 0x3b:	// DEC SP
				sp = (sp - 1) & 0xffff;
			case 0x3c:	// INC A
				a = inc(a);
			case 0x3d:	// DEC A
				a = dec(a);
			case 0x3e:	// LD A,n
				a = readpc();
			case 0x3f:	// CCF
				cf = !cf;
				sf = hf = false;
			case 0x40:	// LD B,B
			case 0x41:	// LD B,C
				b = c;
			case 0x42:	// LD B,D
				b = d;
			case 0x43:	// LD B,E
				b = e;
			case 0x44:	// LD B,H
				b = h;
			case 0x45:	// LD B,L
				b = l;
			case 0x46:	// LD B,(HL)
				b = read(hl);
			case 0x47:	// LD B,A
				b = a;
			case 0x48:	// LD C,B
				c = b;
			case 0x49:	// LD C,C
			case 0x4a:	// LD C,D
				c = d;
			case 0x4b:	// LD C,E
				c = e;
			case 0x4c:	// LD C,H
				c = h;
			case 0x4d:	// LD C,L
				c = l;
			case 0x4e:	// LD C,(HL)
				c = read(hl);
			case 0x4f:	// LD C,A
				c = a;
			case 0x50:	// LD D,B
				d = b;
			case 0x51:	// LD D,C
				d = c;
			case 0x52:	// LD D,D
			case 0x53:	// LD D,E
				d = e;
			case 0x54:	// LD D,H
				d = h;
			case 0x55:	// LD D,L
				d = l;
			case 0x56:	// LD D,(HL)
				d = read(hl);
			case 0x57:	// LD D,A
				d = a;
			case 0x58:	// LD E,B
				e = b;
			case 0x59:	// LD E,C
				e = c;
			case 0x5a:	// LD E,D
				e = d;
			case 0x5b:	// LD E,E
			case 0x5c:	// LD E,H
				e = h;
			case 0x5d:	// LD E,L
				e = l;
			case 0x5e:	// LD E,(HL)
				e = read(hl);
			case 0x5f:	// LD E,A
				e = a;
			case 0x60:	// LD H,B
				h = b;
			case 0x61:	// LD H,C
				h = c;
			case 0x62:	// LD H,D
				h = d;
			case 0x63:	// LD H,E
				h = e;
			case 0x64:	// LD H,H
			case 0x65:	// LD H,L
				h = l;
			case 0x66:	// LD H,(HL)
				h = read(hl);
			case 0x67:	// LD H,A
				h = a;
			case 0x68:	// LD L,B
				l = b;
			case 0x69:	// LD L,C
				l = c;
			case 0x6a:	// LD L,D
				l = d;
			case 0x6b:	// LD L,E
				l = e;
			case 0x6c:	// LD L,H
				l = h;
			case 0x6d:	// LD L,L
			case 0x6e:	// LD L,(HL)
				l = read(hl);
			case 0x6f:	// LD L,A
				l = a;
			case 0x70:	// LD (HL),B
				write(hl, b);
			case 0x71:	// LD (HL),C
				write(hl, c);
			case 0x72:	// LD (HL),D
				write(hl, d);
			case 0x73:	// LD (HL),E
				write(hl, e);
			case 0x74:	// LD (HL),H
				write(hl, h);
			case 0x75:	// LD (HL),L
				write(hl, l);
			case 0x76:	// HALT
				// TODO
				throw "NYI " + StringTools.hex(op, 2);
			case 0x77:	// LD (HL),A
				write(hl, a);
			case 0x78:	// LD A,B
				a = b;
			case 0x79:	// LD A,C
				a = c;
			case 0x7a:	// LD A,D
				a = d;
			case 0x7b:	// LD A,E
				a = e;
			case 0x7c:	// LD A,H
				a = h;
			case 0x7d:	// LD A,L
				a = l;
			case 0x7e:	// LD A,(HL)
				a = read(hl);
			case 0x7f:	// LD A,A
			case 0x80:	// ADD A,B
				a = add(a, b);
			case 0x81:	// ADD A,C
				a = add(a, c);
			case 0x82:	// ADD A,D
				a = add(a, d);
			case 0x83:	// ADD A,E
				a = add(a, e);
			case 0x84:	// ADD A,H
				a = add(a, h);
			case 0x85:	// ADD A,L
				a = add(a, l);
			case 0x86:	// ADD A,(HL)
				a = add(a, read(hl));
			case 0x87:	// ADD A,A
				a = add(a, a);
			case 0x88:	// ADC A,B
				adc(b);
			case 0x89:	// ADC A,C
				adc(c);
			case 0x8a:	// ADC A,D
				adc(d);
			case 0x8b:	// ADC A,E
				adc(e);
			case 0x8c:	// ADC A,H
				adc(h);
			case 0x8d:	// ADC A,L
				adc(l);
			case 0x8e:	// ADC A,(HL)
				adc(read(hl));
			case 0x8f:	// ADC A,A
				adc(a);
			case 0x90:	// SUB A,B
				a = sub(a, b);
			case 0x91:	// SUB A,C
				a = sub(a, c);
			case 0x92:	// SUB A,D
				a = sub(a, d);
			case 0x93:	// SUB A,E
				a = sub(a, e);
			case 0x94:	// SUB A,H
				a = sub(a, h);
			case 0x95:	// SUB A,L
				a = sub(a, l);
			case 0x96:	// SUB A,(HL)
				a = sub(a, read(hl));
			case 0x97:	// SUB A,A
				a = 0;
				hf = cf = false;
				zf = sf = true;
			case 0x98:	// SBC A,B
				sbc(b);
			case 0x99:	// SBC A,C
				sbc(c);
			case 0x9a:	// SBC A,D
				sbc(d);
			case 0x9b:	// SBC A,E
				sbc(e);
			case 0x9c:	// SBC A,H
				sbc(h);
			case 0x9d:	// SBC A,L
				sbc(l);
			case 0x9e:	// SBC A,(HL)
				sbc(read(hl));
			case 0x9f:	// SBC A,A
				if (cf)
				{
					zf = false;
					sf = hf = cf = true;
					a = 0xff;
				}
				else
				{
					hf = cf = false;
					zf = sf = true;
					a = 0;
				}
			case 0xa0:	// AND B
				and(b);
			case 0xa1:	// AND C
				and(c);
			case 0xa2:	// AND D
				and(d);
			case 0xa3:	// AND E
				and(e);
			case 0xa4:	// AND H
				and(h);
			case 0xa5:	// AND L
				and(l);
			case 0xa6:	// AND (HL)
				and(read(hl));
			case 0xa7:	// AND A
				zf = (a == 0);
				hf = true;
				sf = cf = false;
			case 0xa8:	// XOR B
				xor(b);
			case 0xa9:	// XOR C
				xor(c);
			case 0xaa:	// XOR D
				xor(d);
			case 0xab:	// XOR E
				xor(e);
			case 0xac:	// XOR H
				xor(h);
			case 0xad:	// XOR L
				xor(l);
			case 0xae:	// XOR (HL)
				xor(read(hl));
			case 0xaf:	// XOR A
				a = 0;
				zf = true;
				sf = hf = cf = false;
			case 0xb0:	// OR B
				or(b);
			case 0xb1:	// OR C
				or(c);
			case 0xb2:	// OR D
				or(d);
			case 0xb3:	// OR E
				or(e);
			case 0xb4:	// OR H
				or(h);
			case 0xb5:	// OR L
				or(l);
			case 0xb6:	// OR (HL)
				or(read(hl));
			case 0xb7:	// OR A
				zf = a == 0;
				cf = sf = hf = false;
			case 0xb8:	// CMP B
				cmp(b);
			case 0xb9:	// CMP C
				cmp(c);
			case 0xba:	// CMP D
				cmp(d);
			case 0xbb:	// CMP E
				cmp(e);
			case 0xbc:	// CMP H
				cmp(h);
			case 0xbd:	// CMP L
				cmp(l);
			case 0xbe:	// CMP (HL)
				cmp(read(hl));
			case 0xbf:	// CMP A
				cf = hf = false;
				zf = sf = true;
			case 0xc0:	// RET !FZ
				if (!zf)
				{
					pc = popStack();
					ticks += 12;
				}
			case 0xc1:	// POP BC
				bc = popStack();
			case 0xc2:	// JP !FZ,nn
				if (!zf)
				{
					pc = read16pc();
					ticks += 4;
				}
				else
				{
					pc += 2;
				}
			case 0xc3:	// JP nn
				pc = read16pc();
			case 0xc4:	// CALL !FZ,nn
				if (!zf)
				{
					call();
					ticks += 12;
				}
				else
				{
					pc += 2;
				}
			case 0xc5:	// PUSH BC
				pushStack(bc);
			case 0xc6:	// ADD,n
				a = add(a, readpc());
			case 0xc7:	// RST 0
				pushStack(pc);
				pc = 0;
			case 0xc8:	// RET FZ
				if (zf)
				{
					pc = popStack();
					ticks += 12;
				}
			case 0xc9:	// RET
				pc = popStack();
			case 0xca:	// JP FZ,nn
				if (zf)
				{
					pc = read16pc();
					ticks += 4;
				}
				else
				{
					pc += 2;
				}
			case 0xcb:	// secondary op set
				secondaryOp(readpc());
			case 0xcc:	// CALL FZ,nn
				if (zf)
				{
					call();
					ticks += 12;
				}
				else
				{
					pc += 2;
				}
			case 0xcd:	// CALL nn
				call();
			case 0xce:	// ADC A,n
				adc(readpc());
			case 0xcf:	// RST 0x8
				rst(0x8);
			case 0xd0:	// RET !FC
				if (!cf)
				{
					pc = popStack();
					ticks += 12;
				}
			case 0xd1:	// POP DE
				de = popStack();
			case 0xd2:	// JP !FC,nn
				if (!cf)
				{
					pc = read16pc();
					ticks += 4;
				}
				else
				{
					pc += 2;
				}
			// 0xd3 is illegal
			case 0xd4:	// CALL !FC,nn
				if (!cf)
				{
					call();
				}
				else
				{
					pc += 2;
				}
			case 0xd5:	// PUSH DE
				pushStack(de);
			case 0xd6:	// SUB A,n
				a = sub(a, readpc());
			case 0xd7:	// RST 0x10
				rst(0x10);
			case 0xd8:	// RET FC
				if (cf)
				{
					pc = popStack();
					ticks += 12;
				}
			case 0xd9:	// RETI
				pc = popStack();
				ime = true;
			case 0xda:	// JP FC,nn
				if (cf)
				{
					pc = read16pc();
					ticks += 4;
				}
				else
				{
					pc += 2;
				}
			// 0xdb is illegal
			case 0xdc:	// CALL FC,nn
				if (cf)
				{
					call();
					ticks += 12;
				}
				else
				{
					pc += 2;
				}
			// 0xdd is illegal
			case 0xde:	// SBC A,n
				sbc(readpc());
			case 0xdf:	// RST 0x18
				rst(0x18);
			case 0xe0:	// LDH (n),A
				write(0xff00 | readpc(), a);
			case 0xe1:	// POP HL
				hl = popStack();
			case 0xe2:	// LD (0xFF00+C),A
				write(0xFF00 | c, a);
			// 0xe3 is illegal
			// 0xe4 is illegal
			case 0xe5:	// PUSH HL
				pushStack(hl);
			case 0xe6:	// AND n
				and(readpc());
			case 0xe7:	// RST 0x20
				rst(0x20);
			case 0xe8:	// ADD SP,n
				sp = add(sp, readpc());
			case 0xe9:	// JP, (HL)
				pc = hl;
			case 0xea:	// LD n,A
				write(read16pc(), a);
			// 0xeb is illegal
			// 0xec is illegal
			// 0xed is illegal
			case 0xee:
				xor(readpc());
			case 0xef: // RST 0x28
				rst(0x28);
			case 0xf0:	// LDH A,(n)
				a = read(0xff00 | readpc());
			case 0xf1:	// POP AF
				af = popStack();
			case 0xf2:	// LD A,(0xFF00+C)
				a = read(0xFF00 | c);
			case 0xf3:	// DI
				ime = false;
			// 0xf4 is illegal
			case 0xf5:	// PUSH AF
				pushStack(af);
			case 0xf6:	// OR n
				or(readpc());
			case 0xf7:	// RST 0x30
				rst(0x30);
			case 0xf8:	// LDHL SP,n
				var tmp = signed(readpc());
				hl = (sp + tmp) & 0xffff;
				zf = sf = false;
				tmp = sp ^ tmp ^ hl;
				cf = tmp & 0x100 == 0x100;
				hf = tmp & 0x10 == 0x10;
			case 0xf9:	// LD SP,HL
				sp = hl;
			case 0xfa:	// LD A,(nn)
				a = read(read16pc());
			case 0xfb:	// EI
				ime = true;
			// 0xfc is illegal
			// 0xfd is illegal
			case 0xfe:	// CMP n
				cmp(readpc());
			case 0xff:	// RST 0x38
				rst(0x38);

			default:
				throw "Unrecognized opcode: " + StringTools.hex(op);

		}

		pc &= 0xffff;
	}

	inline function secondaryOp(op:Int)
	{
		ticks = tickValues2[op];

		switch (op)
		{
			case 0x00:	// RLC B
				b = rlc(b);
			case 0x01:	// RLC C
				c = rlc(c);
			case 0x02:	// RLC D
				d = rlc(d);
			case 0x03:	// RLC E
				e = rlc(e);
			case 0x04:	// RLC H
				h = rlc(h);
			case 0x05:	// RLC L
				l = rlc(l);
			case 0x06:	// RLC (HL)
				write(hl, rlc(read(hl)));
			case 0x07:	// RLC A
				a = rlc(a);
			case 0x08:	// RRC B
				b = rrc(b);
			case 0x09:	// RRC C
				c = rrc(c);
			case 0x0a:	// RRC D
				d = rrc(d);
			case 0x0b:	// RRC E
				e = rrc(e);
			case 0x0c:	// RRC H
				h = rrc(h);
			case 0x0d:	// RRC L
				l = rrc(l);
			case 0x0e:	// RRC (HL)
				write(hl, rrc(read(hl)));
			case 0x0f:	// RRC A
				a = rrc(a);
			case 0x10:	// RL B
				b = rl(b);
			case 0x11:	// RL C
				c = rl(c);
			case 0x12:	// RL D
				d = rl(d);
			case 0x13:	// RL E
				e = rl(e);
			case 0x14:	// RL H
				h = rl(h);
			case 0x15:	// RL L
				l = rl(l);
			case 0x16:	// RL (HL)
				write(hl, rl(read(hl)));
			case 0x17:	// RL A
				a = rl(a);
			case 0x18:	// RR B
				b = rr(b);
			case 0x19:	// RR C
				c = rr(c);
			case 0x1a:	// RR D
				d = rr(d);
			case 0x1b:	// RR E
				e = rr(e);
			case 0x1c:	// RR H
				h = rr(h);
			case 0x1d:	// RR L
				l = rr(l);
			case 0x1e:	// RR (HL)
				write(hl, rr(read(hl)));
			case 0x1f:	// RR A
				a = rr(a);

			case 0x20:	// SLA B
				b = sla(b);
			case 0x21:	// SLA C
				c = sla(c);
			case 0x22:	// SLA D
				d = sla(d);
			case 0x23:	// SLA E
				e = sla(e);
			case 0x24:	// SLA H
				h = sla(h);
			case 0x25:	// SLA L
				l = sla(l);
			case 0x26:	// SLA (HL)
				write(hl, sla(read(hl)));
			case 0x27:	// SLA A
				a = sla(a);
			case 0x28:	// SRA B
				b = sra(b);
			case 0x29:	// SRA C
				c = sra(c);
			case 0x2a:	// SRA D
				d = sra(d);
			case 0x2b:	// SRA E
				e = sra(e);
			case 0x2c:	// SRA H
				h = sra(h);
			case 0x2d:	// SRA L
				l = sra(l);
			case 0x2e:	// SRA (HL)
				write(hl, sra(read(hl)));
			case 0x2f:	// SRA A
				a = sra(a);
			case 0x30:	// SWAP B
				b = swap(b);
			case 0x31:	// SWAP C
				c = swap(c);
			case 0x32:	// SWAP D
				d = swap(d);
			case 0x33:	// SWAP E
				e = swap(e);
			case 0x34:	// SWAP H
				h = swap(h);
			case 0x35:	// SWAP L
				l = swap(l);
			case 0x36:	// SWAP (HL)
				write(hl, swap(read(hl)));
			case 0x37:	// SWAP A
				a = swap(a);
			case 0x38:	// SRL B
				b = srl(b);
			case 0x39:	// SRL C
				c = srl(c);
			case 0x3a:	// SRL D
				d = srl(d);
			case 0x3b:	// SRL E
				e = srl(e);
			case 0x3c:	// SRL H
				h = srl(h);
			case 0x3d:	// SRL L
				l = srl(l);
			case 0x3e:	// SRL (HL)
				write(hl, srl(read(hl)));
			case 0x3f:	// SRL A
				a = srl(a);
			case 0x40: // BIT 0,B
				bit(b, 0);
			case 0x41: // BIT 0,C
				bit(c, 0);
			case 0x42: // BIT 0,D
				bit(d, 0);
			case 0x43: // BIT 0,E
				bit(e, 0);
			case 0x44: // BIT 0,H
				bit(h, 0);
			case 0x45: // BIT 0,L
				bit(l, 0);
			case 0x46: // BIT 0,(HL)
				bit(read(hl), 0);
			case 0x47: // BIT 0,A
				bit(a, 1);
			case 0x48: // BIT 1,B
				bit(b, 1);
			case 0x49: // BIT 1,C
				bit(c, 1);
			case 0x4a: // BIT 1,D
				bit(d, 1);
			case 0x4b: // BIT 1,E
				bit(e, 1);
			case 0x4c: // BIT 1,H
				bit(h, 1);
			case 0x4d: // BIT 1,L
				bit(l, 1);
			case 0x4e: // BIT 1,(HL)
				bit(read(hl), 1);
			case 0x4f: // BIT 1,A
				bit(a, 1);
			case 0x50: // BIT 2,B
				bit(b, 2);
			case 0x51: // BIT 2,C
				bit(c, 2);
			case 0x52: // BIT 2,D
				bit(d, 2);
			case 0x53: // BIT 2,E
				bit(e, 2);
			case 0x54: // BIT 2,H
				bit(h, 2);
			case 0x55: // BIT 2,L
				bit(l, 2);
			case 0x56: // BIT 2,(HL)
				bit(read(hl), 2);
			case 0x57: // BIT 2,A
				bit(a, 2);
			case 0x58: // BIT 3,B
				bit(b, 3);
			case 0x59: // BIT 3,C
				bit(c, 3);
			case 0x5a: // BIT 3,D
				bit(d, 3);
			case 0x5b: // BIT 3,E
				bit(e, 3);
			case 0x5c: // BIT 3,H
				bit(h, 3);
			case 0x5d: // BIT 3,L
				bit(l, 3);
			case 0x5e: // BIT 3,(HL)
				bit(read(hl), 3);
			case 0x5f: // BIT 3,A
				bit(a, 3);
			case 0x60: // BIT 4,B
				bit(b, 4);
			case 0x61: // BIT 4,C
				bit(c, 4);
			case 0x62: // BIT 4,D
				bit(d, 4);
			case 0x63: // BIT 4,E
				bit(e, 4);
			case 0x64: // BIT 4,H
				bit(h, 4);
			case 0x65: // BIT 4,L
				bit(l, 4);
			case 0x66: // BIT 4,(HL)
				bit(read(hl), 4);
			case 0x67: // BIT 4,A
				bit(a, 4);
			case 0x68: // BIT 5,B
				bit(b, 5);
			case 0x69: // BIT 5,C
				bit(c, 5);
			case 0x6a: // BIT 5,D
				bit(d, 5);
			case 0x6b: // BIT 5,E
				bit(e, 5);
			case 0x6c: // BIT 5,H
				bit(h, 5);
			case 0x6d: // BIT 5,L
				bit(l, 5);
			case 0x6e: // BIT 5,(HL)
				bit(read(hl), 5);
			case 0x6f: // BIT 5,A
				bit(a, 5);
			case 0x70: // BIT 6,B
				bit(b, 6);
			case 0x71: // BIT 6,C
				bit(c, 6);
			case 0x72: // BIT 6,D
				bit(d, 6);
			case 0x73: // BIT 6,E
				bit(e, 6);
			case 0x74: // BIT 6,H
				bit(h, 6);
			case 0x75: // BIT 6,L
				bit(l, 6);
			case 0x76: // BIT 6,(HL)
				bit(read(hl), 6);
			case 0x77: // BIT 6,A
				bit(a, 6);
			case 0x78: // BIT 7,B
				bit(b, 7);
			case 0x79: // BIT 7,C
				bit(c, 7);
			case 0x7a: // BIT 7,D
				bit(d, 7);
			case 0x7b: // BIT 7,E
				bit(e, 7);
			case 0x7c: // BIT 7,H
				bit(h, 7);
			case 0x7d: // BIT 7,L
				bit(l, 7);
			case 0x7e: // BIT 7,(HL)
				bit(read(hl), 7);
			case 0x7f: // BIT 7,A
				bit(a, 7);
			case 0x80: // RES 0,B
				b = res(b, 0);
			case 0x81: // RES 0,C
				c = res(c, 0);
			case 0x82: // RES 0,D
				d = res(d, 0);
			case 0x83: // RES 0,E
				e = res(e, 0);
			case 0x84: // RES 0,H
				h = res(h, 0);
			case 0x85: // RES 0,L
				l = res(l, 0);
			case 0x86: // RES 0,(HL)
				write(hl, res(read(hl), 0));
			case 0x87: // RES 0,A
				a = res(a, 1);
			case 0x88: // RES 1,B
				b = res(b, 1);
			case 0x89: // RES 1,C
				c = res(c, 1);
			case 0x8a: // RES 1,D
				d = res(d, 1);
			case 0x8b: // RES 1,E
				e = res(e, 1);
			case 0x8c: // RES 1,H
				h = res(h, 1);
			case 0x8d: // RES 1,L
				l = res(l, 1);
			case 0x8e: // RES 1,(HL)
				write(hl, res(read(hl), 1));
			case 0x8f: // RES 1,A
				a = res(a, 1);
			case 0x90: // RES 2,B
				b = res(b, 2);
			case 0x91: // RES 2,C
				c = res(c, 2);
			case 0x92: // RES 2,D
				d = res(d, 2);
			case 0x93: // RES 2,E
				e = res(e, 2);
			case 0x94: // RES 2,H
				h = res(h, 2);
			case 0x95: // RES 2,L
				l = res(l, 2);
			case 0x96: // RES 2,(HL)
				write(hl, res(read(hl), 2));
			case 0x97: // RES 2,A
				a = res(a, 2);
			case 0x98: // RES 3,B
				b = res(b, 3);
			case 0x99: // RES 3,C
				c = res(c, 3);
			case 0x9a: // RES 3,D
				d = res(d, 3);
			case 0x9b: // RES 3,E
				e = res(e, 3);
			case 0x9c: // RES 3,H
				h = res(h, 3);
			case 0x9d: // RES 3,L
				l = res(l, 3);
			case 0x9e: // RES 3,(HL)
				write(hl, res(read(hl), 3));
			case 0x9f: // RES 3,A
				a = res(a, 3);
			case 0xa0: // RES 4,B
				b = res(b, 4);
			case 0xa1: // RES 4,C
				c = res(c, 4);
			case 0xa2: // RES 4,D
				d = res(d, 4);
			case 0xa3: // RES 4,E
				e = res(e, 4);
			case 0xa4: // RES 4,H
				h = res(h, 4);
			case 0xa5: // RES 4,L
				l = res(l, 4);
			case 0xa6: // RES 4,(HL)
				write(hl, res(read(hl), 4));
			case 0xa7: // RES 4,A
				a = res(a, 4);
			case 0xa8: // RES 5,B
				b = res(b, 5);
			case 0xa9: // RES 5,C
				c = res(c, 5);
			case 0xaa: // RES 5,D
				d = res(d, 5);
			case 0xab: // RES 5,E
				e = res(e, 5);
			case 0xac: // RES 5,H
				h = res(h, 5);
			case 0xad: // RES 5,L
				l = res(l, 5);
			case 0xae: // RES 5,(HL)
				write(hl, res(read(hl), 5));
			case 0xaf: // RES 5,A
				a = res(a, 5);
			case 0xb0: // RES 6,B
				b = res(b, 6);
			case 0xb1: // RES 6,C
				c = res(c, 6);
			case 0xb2: // RES 6,D
				d = res(d, 6);
			case 0xb3: // RES 6,E
				e = res(e, 6);
			case 0xb4: // RES 6,H
				h = res(h, 6);
			case 0xb5: // RES 6,L
				l = res(l, 6);
			case 0xb6: // RES 6,(HL)
				write(hl, res(read(hl), 6));
			case 0xb7: // RES 6,A
				a = res(a, 6);
			case 0xb8: // RES 7,B
				b = res(b, 7);
			case 0xb9: // RES 7,C
				c = res(c, 7);
			case 0xba: // RES 7,D
				d = res(d, 7);
			case 0xbb: // RES 7,E
				e = res(e, 7);
			case 0xbc: // RES 7,H
				h = res(h, 7);
			case 0xbd: // RES 7,L
				l = res(l, 7);
			case 0xbe: // RES 7,(HL)
				write(hl, res(read(hl), 7));
			case 0xbf: // RES 7,A
				a = res(a, 7);
			case 0xc0: // SET 0,B
				b = set(b, 0);
			case 0xc1: // SET 0,C
				c = set(c, 0);
			case 0xc2: // SET 0,D
				d = set(d, 0);
			case 0xc3: // SET 0,E
				e = set(e, 0);
			case 0xc4: // SET 0,H
				h = set(h, 0);
			case 0xc5: // SET 0,L
				l = set(l, 0);
			case 0xc6: // SET 0,(HL)
				write(hl, set(read(hl), 0));
			case 0xc7: // SET 0,A
				a = set(a, 1);
			case 0xc8: // SET 1,B
				b = set(b, 1);
			case 0xc9: // SET 1,C
				c = set(c, 1);
			case 0xca: // SET 1,D
				d = set(d, 1);
			case 0xcb: // SET 1,E
				e = set(e, 1);
			case 0xcc: // SET 1,H
				h = set(h, 1);
			case 0xcd: // SET 1,L
				l = set(l, 1);
			case 0xce: // SET 1,(HL)
				write(hl, set(read(hl), 1));
			case 0xcf: // SET 1,A
				a = set(a, 1);
			case 0xd0: // SET 2,B
				b = set(b, 2);
			case 0xd1: // SET 2,C
				c = set(c, 2);
			case 0xd2: // SET 2,D
				d = set(d, 2);
			case 0xd3: // SET 2,E
				e = set(e, 2);
			case 0xd4: // SET 2,H
				h = set(h, 2);
			case 0xd5: // SET 2,L
				l = set(l, 2);
			case 0xd6: // SET 2,(HL)
				write(hl, set(read(hl), 2));
			case 0xd7: // SET 2,A
				a = set(a, 2);
			case 0xd8: // SET 3,B
				b = set(b, 3);
			case 0xd9: // SET 3,C
				c = set(c, 3);
			case 0xda: // SET 3,D
				d = set(d, 3);
			case 0xdb: // SET 3,E
				e = set(e, 3);
			case 0xdc: // SET 3,H
				h = set(h, 3);
			case 0xdd: // SET 3,L
				l = set(l, 3);
			case 0xde: // SET 3,(HL)
				write(hl, set(read(hl), 3));
			case 0xdf: // SET 3,A
				a = set(a, 3);
			case 0xe0: // SET 4,B
				b = set(b, 4);
			case 0xe1: // SET 4,C
				c = set(c, 4);
			case 0xe2: // SET 4,D
				d = set(d, 4);
			case 0xe3: // SET 4,E
				e = set(e, 4);
			case 0xe4: // SET 4,H
				h = set(h, 4);
			case 0xe5: // SET 4,L
				l = set(l, 4);
			case 0xe6: // SET 4,(HL)
				write(hl, set(read(hl), 4));
			case 0xe7: // SET 4,A
				a = set(a, 4);
			case 0xe8: // SET 5,B
				b = set(b, 5);
			case 0xe9: // SET 5,C
				c = set(c, 5);
			case 0xea: // SET 5,D
				d = set(d, 5);
			case 0xeb: // SET 5,E
				e = set(e, 5);
			case 0xec: // SET 5,H
				h = set(h, 5);
			case 0xed: // SET 5,L
				l = set(l, 5);
			case 0xee: // SET 5,(HL)
				write(hl, set(read(hl), 5));
			case 0xef: // SET 5,A
				a = set(a, 5);
			case 0xf0: // SET 6,B
				b = set(b, 6);
			case 0xf1: // SET 6,C
				c = set(c, 6);
			case 0xf2: // SET 6,D
				d = set(d, 6);
			case 0xf3: // SET 6,E
				e = set(e, 6);
			case 0xf4: // SET 6,H
				h = set(h, 6);
			case 0xf5: // SET 6,L
				l = set(l, 6);
			case 0xf6: // SET 6,(HL)
				write(hl, set(read(hl), 6));
			case 0xf7: // SET 6,A
				a = set(a, 6);
			case 0xf8: // SET 7,B
				b = set(b, 7);
			case 0xf9: // SET 7,C
				c = set(c, 7);
			case 0xfa: // SET 7,D
				d = set(d, 7);
			case 0xfb: // SET 7,E
				e = set(e, 7);
			case 0xfc: // SET 7,H
				h = set(h, 7);
			case 0xfd: // SET 7,L
				l = set(l, 7);
			case 0xfe: // SET 7,(HL)
				write(hl, set(read(hl), 7));
			case 0xff: // SET 7,A
				a = set(a, 7);
		}
	}

	inline function add(op1:Int, op2:Int)
	{
		var sum = op1 + op2;
		hf = (op1 & 0xf) > (sum & 0xf);
		cf = sum > 0xff;
		sf = false;
		sum &= 0xff;
		zf = sum == 0;
		return sum;
	}

	inline function add16(op1:Int, op2:Int)
	{
		var sum = op1 + op2;
		hf = (op1 & 0xfff) > (sum & 0xfff);
		cf = sum > 0xffff;
		sf = false;
		sum &= 0xffff;
		zf = sum == 0;
		return sum;
	}

	inline function adc(op:Int)
	{
		var carry = cf ? 1 : 0;
		var sum = a + op + carry;
		hf = ((a & 0xf) + (op & 0xf) + carry > 0xf);
		cf = sum > 0xff;
		a = sum & 0xff;
		zf = a == 0;
		sf = false;
	}

	//00 - 88 = 78
	//hf should be false
	inline function sub(op1:Int, op2:Int)
	{
		var sum = op1 - op2;
		cf = sum < 0;
		hf = (op1 & 0xf) < (op2 & 0xf);
		zf = sum == 0;
		sf = true;
		return sum & 0xff;
	}

	inline function sbc(op:Int)
	{
		var carry = cf ? 1 : 0;
		var sum = a - op - carry;
		hf = (a & 0xf) - (op & 0xf) - carry < 0;
		cf = sum < 0;
		a = sum & 0xff;
		zf = a == 0;
		sf = true;
	}

	inline function inc(val:Int)
	{
		val = (val + 1) & 0xff;
		zf = (val == 0);
		hf = (val & 0xf) == 0;
		sf = false;
		return val & 0xff;
	}

	inline function dec(val:Int)
	{
		val = (val - 1) & 0xff;
		zf = val == 0;
		hf = val & 0xf == 0xf;
		sf = true;
		return val & 0xff;
	}

	inline function and(val:Int)
	{
		a &= val;
		zf = (a == 0);
		hf = true;
		sf = cf = false;
	}

	inline function xor(val:Int)
	{
		a ^= val;
		zf = (a == 0);
		sf = hf = cf = false;
	}

	inline function or(val:Int)
	{
		a |= val;
		zf = a == 0;
		sf = cf = hf = false;
	}

	inline function cmp(val:Int)
	{
		var diff = a - val;
		hf = (diff & 0xf) > (a & 0xf);
		cf = diff < 0;
		zf = diff == 0;
		sf = true;
	}

	inline function call()
	{
		var newPc = read16pc();
		pushStack(pc);
		pc = newPc;
	}

	inline function rst(addr:Int)
	{
		pushStack(pc);
		pc = addr;
	}

	inline function rlc(val:Int)
	{
		cf = val > 0x7f;
		val = (val << 1 & 0xff) | (cf ? 1 : 0);
		zf = val == 0;
		sf = hf = false;
		return val & 0xff;
	}

	inline function rrc(val:Int)
	{
		cf = (val & 1) == 1;
		val = (val >> 1 & 0xff) | (cf ? 0x80 : 0);
		zf = val == 0;
		sf = hf = false;
		return val & 0xff;
	}

	inline function rl(val:Int)
	{
		var newCf = val > 0x7f;
		val = ((val << 1) & 0xff) | (cf ? 1 : 0);
		cf = newCf;
		hf = sf = false;
		zf = val == 0;
		return val & 0xff;
	}

	inline function rr(val:Int)
	{
		var newCf = (val & 1) == 1;
		val = ((val >> 1) & 0xff) | (cf ? 0x80 : 0);
		cf = newCf;
		hf = sf = false;
		zf = val == 0;
		return val & 0xff;
	}

	inline function sla(val:Int)
	{
		cf = val > 0x7f;
		val = (val << 1) & 0xff;
		hf = sf = false;
		zf = val == 0;
		return val;
	}

	inline function sra(val:Int)
	{
		cf = (val & 1) == 1;
		val = (val & 0x80) | (val >> 1);
		hf = sf = false;
		zf = val == 0;
		return val & 0xff;
	}

	inline function swap(val:Int)
	{
		val = ((val & 0xf) << 4) | (val >> 4);
		zf = val == 0;
		cf = hf = sf = false;
		return val & 0xff;
	}

	inline function srl(val:Int)
	{
		cf = (val & 1) == 1;
		val >>= 1;
		hf = sf = false;
		zf = val == 0;
		return val & 0xff;
	}

	inline function bit(val:Int, n:Int)
	{
		hf = true;
		sf = false;
		zf = !Util.getbit(val, n);
	}

	inline function res(val:Int, n:Int)
	{
		return Util.setbit(val, n, false);
	}

	inline function set(val:Int, n:Int)
	{
		return Util.setbit(val, n, true);
	}

	inline function readpc()
	{
		return read((pc++) & 0xffff);
	}

	inline function read16pc()
	{
		var val = read16(pc);
		pc += 2;
		return val;
	}

	inline function read(addr:Int)
	{
#if cputrace
		//log += " R" + StringTools.hex(addr, 4);
		var val = cart.read(addr) & 0xff;
		//log += "=" + StringTools.hex(val, 2);
		return val;
#else
		return cart.read(addr) & 0xff;
#end
	}

	inline function read16(addr:Int)
	{
		return read(addr) | (read(addr+1) << 8);
	}

	inline function write(addr:Int, value:Int)
	{
#if cputrace
		//log += " W" + StringTools.hex(addr, 4);
		//log += "=" + StringTools.hex(value & 0xff, 2);
#end
		cart.write(addr, value & 0xff);
	}

	inline function write16(addr:Int, value:Int)
	{
		write(addr, value);
		write(addr+1, value >> 8);
	}

	inline function pushStack(val:Int)
	{
		write((--sp) & 0xffff, val >> 8);
		write((--sp) & 0xffff, val & 0xff);
		sp &= 0xffff;
	}

	inline function popStack()
	{
		return (read(sp++) | (read(sp++) << 8)) & 0xffff;
	}

	inline function signed(n:Int)
	{
		return n > 0x80 ? (n - 0x100) : n;
	}

	inline function interrupt(i:Int)
	{
		interruptsRequested[i] = false;
		ime = false;
		//trace("INTERRUPT", cycleCount, i);
		pushStack(pc);
		pc = Interrupt.vectors[i];
		ticks += 20;
	}

	static var tickValues:Vector<Int> = Vector.fromArrayCopy([
	/*   0,  1,  2,  3,  4,  5,  6,  7,  8,  9,  A,  B,  C,  D,  E,  F*/
		 4, 12,  8,  8,  4,  4,  8,  4, 20,  8,  8,  8,  4,  4,  8,  4,  //0
		 4, 12,  8,  8,  4,  4,  8,  4, 12,  8,  8,  8,  4,  4,  8,  4,  //1
		 8, 12,  8,  8,  4,  4,  8,  4,  8,  8,  8,  8,  4,  4,  8,  4,  //2
		 8, 12,  8,  8, 12, 12, 12,  4,  8,  8,  8,  8,  4,  4,  8,  4,  //3
		 4,  4,  4,  4,  4,  4,  8,  4,  4,  4,  4,  4,  4,  4,  8,  4,  //4
		 4,  4,  4,  4,  4,  4,  8,  4,  4,  4,  4,  4,  4,  4,  8,  4,  //5
		 4,  4,  4,  4,  4,  4,  8,  4,  4,  4,  4,  4,  4,  4,  8,  4,  //6
		 8,  8,  8,  8,  8,  8,  4,  8,  4,  4,  4,  4,  4,  4,  8,  4,  //7
		 4,  4,  4,  4,  4,  4,  8,  4,  4,  4,  4,  4,  4,  4,  8,  4,  //8
		 4,  4,  4,  4,  4,  4,  8,  4,  4,  4,  4,  4,  4,  4,  8,  4,  //9
		 4,  4,  4,  4,  4,  4,  8,  4,  4,  4,  4,  4,  4,  4,  8,  4,  //A
		 4,  4,  4,  4,  4,  4,  8,  4,  4,  4,  4,  4,  4,  4,  8,  4,  //B
		 8, 12, 12, 16, 12, 16,  8, 16,  8, 16, 12,  0, 12, 24,  8, 16,  //C
		 8, 12, 12,  4, 12, 16,  8, 16,  8, 16, 12,  4, 12,  4,  8, 16,  //D
		12, 12,  8,  4,  4, 16,  8, 16, 16,  4, 16,  4,  4,  4,  8, 16,  //E
		12, 12,  8,  4,  4, 16,  8, 16, 12,  8, 16,  4,  0,  4,  8, 16   //F
	]);
	static var tickValues2:Vector<Int> = Vector.fromArrayCopy([
	/*  0, 1, 2, 3, 4, 5,  6, 7, 8, 9, A, B, C, D,  E, F*/
		8, 8, 8, 8, 8, 8, 16, 8, 8, 8, 8, 8, 8, 8, 16, 8,  //0
		8, 8, 8, 8, 8, 8, 16, 8, 8, 8, 8, 8, 8, 8, 16, 8,  //1
		8, 8, 8, 8, 8, 8, 16, 8, 8, 8, 8, 8, 8, 8, 16, 8,  //2
		8, 8, 8, 8, 8, 8, 16, 8, 8, 8, 8, 8, 8, 8, 16, 8,  //3
		8, 8, 8, 8, 8, 8, 12, 8, 8, 8, 8, 8, 8, 8, 12, 8,  //4
		8, 8, 8, 8, 8, 8, 12, 8, 8, 8, 8, 8, 8, 8, 12, 8,  //5
		8, 8, 8, 8, 8, 8, 12, 8, 8, 8, 8, 8, 8, 8, 12, 8,  //6
		8, 8, 8, 8, 8, 8, 12, 8, 8, 8, 8, 8, 8, 8, 12, 8,  //7
		8, 8, 8, 8, 8, 8, 16, 8, 8, 8, 8, 8, 8, 8, 16, 8,  //8
		8, 8, 8, 8, 8, 8, 16, 8, 8, 8, 8, 8, 8, 8, 16, 8,  //9
		8, 8, 8, 8, 8, 8, 16, 8, 8, 8, 8, 8, 8, 8, 16, 8,  //A
		8, 8, 8, 8, 8, 8, 16, 8, 8, 8, 8, 8, 8, 8, 16, 8,  //B
		8, 8, 8, 8, 8, 8, 16, 8, 8, 8, 8, 8, 8, 8, 16, 8,  //C
		8, 8, 8, 8, 8, 8, 16, 8, 8, 8, 8, 8, 8, 8, 16, 8,  //D
		8, 8, 8, 8, 8, 8, 16, 8, 8, 8, 8, 8, 8, 8, 16, 8,  //E
		8, 8, 8, 8, 8, 8, 16, 8, 8, 8, 8, 8, 8, 8, 16, 8   //F
	]);
}
