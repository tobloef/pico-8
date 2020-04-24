pico-8 cartridge // http://www.pico-8.com
version 20
__lua__
-- you only tap once
-- by tobias lofgren
-- demake of an old game i made
-- https://play.google.com/store/apps/details?id=com.tobloef.yoto.android

dt=nil--delta time
ft=0--fade timer
tau=6.283--pi*2
dts={}--dots
hdts={}--hit dots
db1,db2="",""--debug texts
omb=0--old mouse button value
lvl=nil--current level
rate=0.3--growth/shrink rate
wait=1.5--time before shrink
--old mouse coords
omx,omy=nil,nil
curx,cury=63,63--cusor coords
--input button to directions
bdx,bdy={-1,1,0,0},{0,0,-1,1}
tpd=false--if player has tapped
gst=0--game state:
					--playing=0
     --won=1
     --lost=-1
lpt=0
hits=0
done_time=nil

function _init()
	poke(0x5f2d, 1)--enable mouse
	tpd=false
	gst=0
	lpt=0
	hits=0
	done_time=nil
	lvl=random_level()
	spawn_dots()
end

function _update60()
	update_dt()
	update_input()
	move_dots()
	resize_dots()
	collide_dots()
	check_goal()
	if (#dts==0 and #hdts==0) then
		if (done_time==nil) then
			done_time=time()
		end
	end
	if (done_time!=nil) then
		if (time()-done_time>=1) then
			_init()
		end
	end
end

function _draw()
	background()
	draw_dots()
	draw_progress()
	draw_debug()
	--raw_perf()
	draw_cursor()
end

function update_dt()
	if (dt==nil) then
		dt=1/stat(8) 
	end
end

function update_input()
	nmb=stat(34)
	mx,my=stat(32),stat(33)
	ncurx,ncury=curx,cury
	clck=omb==1 and nmb==0
	prsd=btnp(4) or btnp(5)
	if (clck or prsd) then
		if (not tpd) then
			d=new_click_dot(curx,cury)
			add(hdts,d)
			tpd=true
		end
	end
	if (mx!=omx or my!=omy) then
		omx,omy=mx,my
		ncurx,ncury=mx,my
	end
	for i=0,3 do
		if (btn(i)) then
			ncurx+=bdx[i+1]
			ncury+=bdy[i+1]
		end
	end
	curx=min(max(ncurx,0),127)
	cury=min(max(ncury,0),127)
	omb=nmb
end

function shrink_all()
	freeze_hits=true
	for i=#dts,1,-1 do
		hdts[i]=dts[i]
		hdts[i].st=3
		del(dts,dts[i])
	end
end

function check_goal()
	prgr=lvl.count-#dts
	won=prgr>=lvl.goal
	done=tpd and #hdts==0
	wsz=gst==0
	if (wsz and won) then
		gst=1
	elseif (done and not won) then
		gst=-1
	end
	if (done) then
		shrink_all()
	end
end
-->8
function background()
	if (gst==1) then
		if (ft<0.1) then
			ft+=dt
			cls(3)
		else
			cls(11)
		end
	elseif (gst==-1) then
		if (ft<0.1) then
			ft+=dt
			cls(13)
		elseif (ft<0.2) then
			ft+=dt
			cls(2)
		else
			cls(8)
		end
	else
		cls(12)
	end
end

function draw_dot_shadow(d)
	circfill(d.x+2,d.y+2,d.size,5)
end

function draw_dot(d)
	circfill(d.x,d.y,d.size,7)
end

function draw_dots()
	foreach(dts,draw_dot_shadow)
	foreach(hdts,draw_dot_shadow)
	foreach(dts,draw_dot)
	foreach(hdts,draw_dot)
end

function draw_perf()
	print(stat(1),1,1,0)
	print(stat(7),1,7,0)
end

function draw_debug()
	print(db1,1,110,0)
	print(db2,1,116,0)
end

function draw_cursor()
	spr(1,curx,cury)
end

function draw_progress()
	g=lvl.goal
	t=tostr(hits).."/"..tostr(g)
	print(t,3,3,5)
	print(t,2,2,7)
end
-->8
function wall_collide(d)
	--walls
	lw=d.x-d.size<0
	rw=d.x+d.size>127
	tw=d.y-d.size<0
	bw=d.y+d.size>127
	--travel direction
	ld=d.velx<0
	rd=d.velx>0
	td=d.vely<0
	bd=d.vely>0
	--hit wall and moving onto it 
	--to prevent getting stuck
	l=lw and ld
	r=rw and rd
	t=tw and td
	b=bw and bd
	--hit left/right wall
	if	l or r then
		d.velx=-d.velx
	--hit top/bottom wall
	elseif t or b then
		d.vely=-d.vely
	end
end

function dot_collide(d,i)
	for j=#hdts,1,-1 do
		hd=hdts[j]
		dx=abs(d.x-hd.x)
		dy=abs(d.y-hd.y)
		md=d.size+hd.size
		if (dx<=md and dy<=md) then
			dst=dx*dx+dy*dy--squared
			min_dst=md*md--squared
			if (dst<=min_dst) then
				if (time()-lpt>0.05) then
					lpt=time()
					pitch=flr(rnd(10))+30
					poke(0x3200,pitch)
					sfx(0)
				end
				d.st=2
				if (not freeze_hits) then
					hits+=1
				end
				add(hdts,d)
				del(dts,dts[i])
				break
			end
		end
	end
end

function collide_dots()
	for i=#dts,1,-1 do
		wall_collide(dts[i])
		dot_collide(dts[i],i)
	end
end
-->8
function spawn_dots()
	dts={}
	hdts={}
	for i=0,lvl.count do
		dts[i]=new_dot()
	end
end

function new_dot()
	angl=rnd(tau)
	return {
		x=rnd(128-lvl.size),
		y=rnd(128-lvl.size),
		velx=cos(angl)*lvl.vel,
		vely=sin(angl)*lvl.vel,
		size=lvl.size,
		sgt=nil,--stopped grow time
		st=0--dot state:
						--0=moving
						--1=hit
						--2=hit and growing
						--3=hit and shrinking
	}
end

function new_click_dot(x,y)
	return {
		x=x,
		y=y,
		velx=0,
		vely=0,
		size=0,
		sgt=nil,
		st=2
	}
end

function move_dots()
	for d in all(dts) do
		d.x+=d.velx*dt
		d.y+=d.vely*dt
	end 
end

function resize_dots()
	max_size=lvl.size*lvl.growth
	for i=#hdts,1,-1 do
		d=hdts[i]
		if (d.st==1) then
			if (time()-d.sgt>wait) then
				d.st=3
			end
		elseif (d.st==2) then
			d.size+=rate
			if (d.size>=max_size) then
				d.size=max_size
				d.st=1
				d.sgt=time()
			end
		elseif (d.st==3) then
			d.size-=rate
			if (d.size<=0) then
				del(hdts,hdts[i])
			end
		end
	end
end
-->8
function random_level()
	c=flr(rnd(99))+1
	return {
		size=rnd(3)+0.5,
		growth=rnd(3)+2,
		vel=rnd(90)+10,
		count=c,
		goal=max(1,flr(rnd(c/2)+c/2))
	}
end

function test_level()
	return {
		size=2,
		growth=5,
		vel=50,
		count=30,
		goal=30
	}
end

function proc_level()
	
end
__gfx__
00000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000171000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700177100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000177710000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000177771000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700177110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000011710000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
000400003f05102000000000000008500035000150000700007000110001100011000110001100011000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__music__
00 00424344

