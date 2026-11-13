pico-8 cartridge // http://www.pico-8.com
version 43
__lua__
-- tools --
function split2d(s)
	local arr=split(s,"|",false)
	for k,v in pairs(arr) do
		arr[k]=split(v)
	end
	return arr
end

function spawnp()
	return unpack(spawns[lvl])
end

function overlap(ax,ay,aw,ah,bx,by,bw,bh)
	return ax<bx+bw and bx<ax+aw and ay<by+bh and by<ay+ah
end

function scan_map()
	ledges={}
	plats={}
	ride=nil
	hold=nil
	air=nil
	for y=mymin/8,mymax/8 do
		local ledge=nil
		local run=nil
		for x=mxmin/8,mxmax/8 do
			local tle=mget(x,y)
			parse_tile(tle,x,y)
			if tle==92 or tle==93 or tle==94 then
				if run and run.sp==tle then
					run.w+=8
				else
					run={
						sp=tle,pos=0,dir=1,
						sx=0,sy=0,
						hx=x*8,hy=y*8,
						w=8,h=8
					}
					add(plats,run)
				end
				if tle!=92 then
					mset(x,y,0)
				end
				ledge=nil
			elseif fget(tle,2) then
				run=nil
				if not ledge then
					ledge={
						t=0,stage=0,cells={},
						x=x*8,y=y*8,w=0
					}
					add(ledges,ledge)
				end
				add(ledge.cells,{x=x,y=y,sp=tle})
				ledge.w+=8
			else
				ledge=nil
				run=nil
			end
		end
	end
	plant_spawn()
end

function parse_tile(tle,x,y)
	local _x,_y=x*8,y*8
	local k=enemy_kinds[tle]
	if k then
		make_en(k,_x,_y)
		mset(x,y,0)
	elseif tle==112 then
		add(hearts,{x=_x,y=_y})
		mset(x,y,0)
	end
end

ledge_anim={fr=15,125,126,127}

function ledge_paint(l,s)
	for c in all(l.cells) do
		mset(c.x,c.y,s or c.sp)
	end
end

function ledge_hit(l,x,y,w,h)
	for c in all(l.cells) do
		if overlap(x,y,w,h,c.x*8,c.y*8,8,8) then
			return true
		end
	end
end

function ledge_break(l)
	for c in all(l.cells) do
		mset(c.x,c.y,0)
	end
	l.gone=90
	if hold==l then hold=nil end
	actions.notify("brk")
end

function upd_ledge(l)
	if l.gone then
		if l.gone>0 then l.gone-=1 end
		if l.gone>0 or ledge_hit(l,player.x,player.y,16,16) then
			return
		end
		ledge_paint(l)
		l.gone=nil
		l.t=0
		l.stage=0
		return
	end

	local fr=ledge_anim.fr
	if hold==l then
		l.t+=7
		if l.t>=fr*(#ledge_anim+1) then
			ledge_break(l)
			return
		end
		local stage=l.t\fr
		if stage>l.stage then
			l.stage=stage
			ledge_paint(l,ledge_anim[stage])
		end
	else
		l.t=max(l.t-1,0)
		local prev=l.stage-1
		if l.stage>0 and l.t<=fr*prev then
			l.stage=prev
			ledge_paint(l,prev>0 and ledge_anim[prev])
		end
	end
end

function upd_ledges()
	for l in all(ledges) do
		upd_ledge(l)
	end
end

plats={}
ride=nil
hold=nil
air=nil

plats={}
ride=nil
hold=nil
air=nil

function plat_at(p)
	local x,y=p.hx,p.hy
	if p.sp==93 then
		x+=flr(p.pos)
	elseif p.sp==94 then
		y-=flr(p.pos)
	end
	return x,y
end

function upd_plats()
	for p in all(plats) do
		if p.sp==92 then
			p.sx,p.sy=0,0
		else
			local plat_spd=0.75
			local pos=p.pos+plat_spd*p.dir
			local dir=p.dir
			if pos>=32 then
				pos=32
				dir=-1
			elseif pos<=0 then
				pos=0
				dir=1
			end
			local d=flr(pos)-flr(p.pos)
			local dx,dy=d,0
			if p.sp==94 then
				dx,dy=0,-d
			end
			if ride==p and (dx!=0 or dy!=0)
			and cmap(player,player.x+dx,player.y+dy) then
				p.dir=-p.dir
				p.sx,p.sy=0,0
			else
				p.pos,p.dir=pos,dir
				p.sx,p.sy=dx,dy
				if ride==p then
					player.x+=dx
					player.y+=dy
				end
			end
		end
	end
end

function over_x(p,px)
	local fx=player.x+player.hx
	return fx<px+p.w and px<fx+player.hw
end

function on_plat(p)
	local px,py=plat_at(p)
	local fx=player.x+player.hx
	local fy=player.y+player.hy+1
	return overlap(fx,fy,player.hw,player.hh,px,py,p.w,1)
end

function plant_spawn()
	ride=nil
	hold=nil
	air=nil
	for p in all(plats) do
		if on_plat(p) then
			ride=p
			player.onground=true
			return
		end
	end
end

function air_shift()
	if not air or air.sx==0 then return end
	local s=sgn(air.sx)
	for i=1,abs(air.sx) do
		if cmap(player,player.x+s,player.y) then
			break
		end
	end
end

function stick_ride()
	if not ride then return end
	local px,py=plat_at(ride)
	local feet=player.y+16
	if over_x(ride,px) and feet>=py and feet<=py+1 then
		player.y=py-16
		player.dy=0
		player.ay=0
	else
		ride=nil
	end
end

function stick_hold()
	if not hold or hold.gone then
		hold=nil
		return
	end
	local feet=player.y+16
	local py=hold.y
	if over_x(hold,hold.x) and feet>=py and feet<=py+1 then
		player.y=py-16
		player.dy=0
		player.ay=0
	else
		hold=nil
	end
end

function try_board(y0)
	if ride then return end
	if player.y<=y0 and player.dy<=0 then return end
	local b0=y0+16
	local b1=player.y+16
	local best,by,onledge
	for p in all(plats) do
		local px,py=plat_at(p)
		local prev=py-p.sy
		if b0<=prev and b1>=py and over_x(p,px) then
			if not best or py<by then
				best,by,onledge=p,py,false
			end
		end
	end
	for l in all(ledges) do
		if not l.gone then
			local py=l.y
			if b0<=py and b1>=py and over_x(l,l.x) then
				if not best or py<by then
					best,by,onledge=l,py,true
				end
			end
		end
	end
	if not best then return end
	player.y=by-16
	player.dy=0
	player.ay=0
	air=nil
	if onledge then
		hold=best
	else
		ride=best
		hold=nil
	end
end

function draw_plats()
	for p in all(plats) do
		if p.sp!=92 then
			local x,y=plat_at(p)
			for i=0,p.w/8-1 do
				spr(p.sp,x+i*8,y)
			end
		end
	end
end

function color_lvl(lvl)
	pal(14,135,1)
	pal(10,131,1)
	pal(15,143,1)
	if lvl==1 then
		pal(11,138,1)
		pal(12,140,1)
	elseif lvl==2 then
		pal(3,130,1)
		pal(11,136,1)
		pal(12,128,1)
	else
		pal(3,137,1)
		pal(11,9,1)
		pal(12,130,1)
	end
end
-->8
-- main
function _init()
	poke(0x5f00+92,255)
	maplvl=split2d"0,128,0,896|192,320,0,896|0,512,896,1024"
	spawns=split2d"24,104|0,296|895,448"
	lvl=1
	t=0
	stocks=2
	card="title"
	title_arm=false
	jump_arm=false
	init_audio()
	anim_init(player,anims,"idle")
	player.x=56
	player.y=56
	player.dir=0
	--placeholder music(x, 0, 1)
end

function restart()
	player.hp=player.maxhp
	load_level()
end

function next_level()
	if lvl<#maplvl then
		lvl+=1
		load_level()
	end
end

function load_level()
	reload(0x1000,0x1000,0x2000)

	mymin,mymax,mxmin,mxmax=unpack(maplvl[lvl])
	camera()

	player.x, player.y=spawnp()
	player.dx,player.dy,player.ax,player.ay=0,0,0,0
	player.onground=true
	player.jbuf=0
	jump_arm=false
	player.invul=0
	player.knock=0
	player.hop=false
	player.fate=nil
	hbt={0,0,0}
	hbs={0,0,0}
	shake=0
	anim_init(player,anims,"idle")

	ens={}
	rocks={}
	hearts={}

	scan_map()
	upd_cam()
	seed_clouds()
	pal()
	if fade then return end
	if lvl==1 then
		music(0,0,1)
	elseif lvl==2 then
		music(9,0,1)
	else
		music(-1)
	end
end

heart_fr={112,123,124,123}

function heart_sp()
	return heart_fr[(t\8)%4+1]
end

function take_hearts(p)
	local before=p.hp
	for h in all(hearts) do
		if p.hp<p.maxhp
		and overlap(p.x,p.y,16,16,h.x,h.y+1,8,7) then
			p.hp=min(p.hp+2,p.maxhp)
			del(hearts,h)
			actions.notify("heal")
		end
	end
	if p.hp!=before then
		hearts_changed(before,p.hp,false)
	end
end

function make_en(k,ex,ey)
	local e={
		sp=k.sp,
		sw=k.w,sh=k.h,
		x=ex,y=ey,
		dx=0,dy=0,ax=0,ay=0,
		dir=-1,
		g=0.5,
		hx=0,hy=0,
		hw=8,hh=k.h*8,
		cm=true,cw=false,
		dmg=k.dmg,
		chase=k.chase,
		push=k.push,
		sm={current=nil}
	}
	anim_init(e,k.anim,"walk")
	sm_change(e,st_patrol)
	add(ens,e)
end

function begin_death()
	player.dx=0
	player.dy=0
	player.jbuf=0
	player.play="hold"
	player.fate="die"
	music(-1)
	actions.notify("die")
	animate(player)
end

function begin_angel()
	player.y=cy+114
	player.dx=0
	player.dy=0
	player.dir=0
	player.jbuf=0
	player.play="angel"
	player.fate="angel"
	player.t=0
	music(-1)
	actions.notify("die")
end

function update_fate()
	if player.fate=="angel" then
		if player.t>=60 then
			open_card()
			return
		end
		player.y-=2
		player.t+=1
		animate(player)
	else
		animate(player)
		if player.done then
			open_card()
		end
	end
end

function open_card()
	if stocks==0 then
		card="over"
		card_t=0
		card_arm=false
		player.jbuf=0
	else
		stocks-=1
		restart()
	end
end

function open_ending()
	card="end"
	card_t=0
	card_arm=false
end

function title_word()
	print("TATRAS",0,0,7)
	for py=0,5 do
		for px=0,23 do
			if pget(px,py)==7 then
				rectfill(41+px*2,17+py*2,42+px*2,18+py*2,0)
				rectfill(40+px*2,16+py*2,41+px*2,17+py*2,2)
			end
		end
	end
	rectfill(0,0,23,5,12)
end

function update_title()
	animate(player)
	if not title_arm then
		if not btn(4) and not btn(5) then
			title_arm=true
		end
		return
	end
	if btnp(4) or btnp(5) then
		begin_fade("play")
	end
end

function draw_title()
	camera()
	pal()
	pal(12,131,1)
	pal(2,134,1)
	pal(9,142,1)
	cls(12)
	spr(player.sp,player.x,player.y,2,2)
	title_word()
	print("Z/X TO JUMP",40,90,7)
	if t%30<20 then
		print("PRESS Z/X TO START",28,102,7)
	end
end

function update_card()
	if card=="title" then
		update_title()
		return
	end
	if card=="end" then
		update_ending()
		return
	end
	card_t+=1
	if card_t<60 then
		return
	end
	if btn()==0 then
		card_arm=true
	end
	if card_arm and btnp() then
		stocks=2
		lvl=1
		card=nil
		restart()
	end
end

function update_ending()
	card_t+=1
	if card_t<330 then
		return
	end
	if not card_arm then
		if not btn(4) and not btn(5) then
			card_arm=true
		end
		return
	end
	if btnp(4) or btnp(5) then
		begin_fade("title")
	end
end

function draw_card()
	if card=="title" then
		draw_title()
		return
	end
	if card=="end" then
		draw_ending()
		return
	end
	camera()
	pal()
	cls(8)
	print("GAME OVER",46,61,0)
end

ink={142,136,132,128,0}
paper={7,6,5,133,0}
dark={
	[0]=0,129,128,131,132,133,5,6,
	136,4,9,3,1,1,136,136,
	[128]=0,[129]=0,[130]=128,[131]=129,
	[132]=128,[133]=0,[135]=4,[136]=132,
	[137]=4,[142]=136,[143]=136
}

function fade_game(age)
	local n=age\3
	for i=0,15 do
		local c=peek(0x5f10+i)
		for k=1,n do
			c=dark[c] or 0
		end
		pal(i,c,1)
	end
end

function begin_fade(to)
	fade={age=0,to=to}
	player.jbuf=0
	music(-1,500)
end

function fade_lvl_music()
	if lvl==1 then
		music(0,500,1)
	elseif lvl==2 then
		music(9,500,1)
	else
		--placeholder music(x, 500, 1)
	end
end

function fade_land()
	local to=fade.to
	fade.up=true
	fade.age=0
	if to=="end" then
		open_ending()
		--placeholder music(x, 500, 1)
		fade=nil
		return
	end
	if to=="play" then
		stocks=2
		lvl=1
		card=nil
		restart()
		fade_lvl_music()
	elseif to=="lvl" then
		next_level()
		fade_lvl_music()
	else
		card="title"
		title_arm=false
		player.x=56
		player.y=56
		player.dir=0
		anim_init(player,anims,"idle")
		animate(player)
		--placeholder music(x, 500, 1)
	end
end

function ramp(a,age,up)
	local i=age\3
	if up then i=4-i end
	return a[i+1]
end

function ending_inks()
	local c9,c7=142,0
	if card_t<15 then
		c9=ramp(ink,card_t,true)
	elseif card_t<210 then
		c9=142
	elseif card_t<225 then
		c9=ramp(ink,card_t-210)
	elseif card_t<240 then
		c9=ramp(ink,card_t-225,true)
	end
	if card_t>=330 then
		c7=7
	elseif card_t>=105 and card_t<120 then
		c7=ramp(paper,card_t-105,true)
	elseif card_t>=120 and card_t<210 then
		c7=7
	elseif card_t>=210 and card_t<225 then
		c7=ramp(paper,card_t-210)
	end
	return c9,c7
end

function draw_ending()
	local c9,c7=ending_inks()
	camera()
	pal()
	pal(9,c9,1)
	pal(7,c7,1)
	cls(0)
	if card_t<225 then
		print("Home sweet home♥",34,61,9)
		if card_t>=105 then
			print("FIN",112,120,7)
		end
		return
	end
	print("Thank you for playing",22,61,9)
	if card_t>=330 and t%30<20 then
		print("PRESS Z/X TO GO BACK",24,80,7)
		print("TO THE TITLE SCREEN",26,88,7)
	end
end

function cloud_y()
	if lvl==3 then
		return cy+rnd(112)
	end
	return cy+4+rnd(40)
end

function mk_cloud(x)
	add(clouds,{
		x=x,
		y=cloud_y(),
		spd=rnd(0.2)+0.2,
		flip=rnd(2)<1
	})
end

function seed_clouds()
	clouds={}
	if lvl==2 then return end
	for i=1,3 do
		mk_cloud(cx+rnd(96))
	end
end

function upd_clouds()
	if lvl==2 then return end
	if #clouds<4 and t%60==0 then
		mk_cloud(cx+128)
	end
	for c in all(clouds) do
		c.x-=c.spd
		if c.x+32<cx then
			del(clouds,c)
		end
	end
end

function draw_clouds()
	camera(cx+cam_shake(),cy)
	for c in all(clouds) do
		spr(103,c.x,c.y,4,2,c.flip)
	end
end

function _update()
	t+=1
	if t>=32000 then
		t-=32000
	end

	if fade then
		fade.age+=1
		if fade.age>=15 then
			if fade.up then
				fade=nil
			else
				fade_land()
			end
		end
		return
	end

	upd_fx()

	if card then
		update_card()
		return
	end

	if player.fate then
		update_fate()
		return
	end

	player:update()
	if player.fate then
		return
	end

	for e in all(ens) do
		sm_update(e)
	end
	resolve_enemies()
	if player.fate then
		return
	end

	if (lvl==3) upd_rocks()
	if player.fate then
		return
	end

	if player.y>mymax then
		begin_angel()
		update_fate()
		return
	end	

	if tmap(player,1) then
		if lvl==3 then
			begin_fade("end")
		else
			begin_fade("lvl")
		end
		return
	end
	upd_clouds()
	upd_cam()
end

function _draw()
	if card then
		draw_card()
	else
		cls(12)
		draw_clouds()
		mapcam()
		map()
		draw_plats()
		for e in all(ens) do
			spr(e.sp,e.x,e.y,e.sw,e.sh,e.dir~=-1)
			if e.sm.current==st_chase then
				spr(118,e.x+12,e.y-8)
			end
		end
		for r in all(rocks) do
			spr(r.sp,r.x,r.y)
		end
		for h in all(hearts) do
			spr(heart_sp(),h.x,h.y)
		end
		player:draw()
		color_lvl(lvl)
		camera()
		drw_hud()
	end
	if fade then
		local age=fade.age
		if fade.up then
			age=14-age
		end
		fade_game(age)
	end
end

hbt={0,0,0}
hbs={0,0,0}
shake=0

function heart_fill(n)
	if n>=2 then return 2 end
	if n==1 then return 1 end
	return 0
end

function hearts_changed(old,new,hit)
	for i=1,3 do
		local a=heart_fill(old-(i-1)*2)
		local b=heart_fill(new-(i-1)*2)
		if a!=b then
			local hi=max(a,b)
			hbs[i]=hi==2 and 113 or 115
			hbt[i]=6
		end
	end
	if hit then
		shake=6
	end
end

function upd_fx()
	for i=1,3 do
		if hbt[i]>0 then
			hbt[i]-=1
		end
	end
	if shake>0 then
		shake-=1
	end
end

function cam_shake()
	if shake<=0 then return 0 end
	return shake%2==0 and -2 or 2
end

function drw_hud()
	for i=1,3 do
		local n=player.hp-(i-1)*2
		local s=116
		if hbt[i]>0 then
			s=hbs[i]
		elseif n>=2 then
			s=112
		elseif n==1 then
			s=114
		end
		spr(s,2+(i-1)*9,2)
	end
	spr(117,109,2)
	print("x"..stocks,118,3,7)
end
-->8
-- player
player = {
    x=0,
    y=61,
    dx=0,
    dy=0,
    ax=0,
    ay=0,
    dir=2,    -- 0=left, 1=right, 2=up, 3=down
    sp=1,
    speed=2,
	maxhp=6,
	hp=6,
	invul=0,
	knock=0,
	kdx=0,
	hop=false,
	-- jump values --
	onground=true,
	jbuf=0,
    initaccel= -5,
    g=0.5,
    -- feet hitbox --
    hx=4,
    hy=10,
    hw=8,
    hh=6,
    cm=true,  -- collide with map tiles
    cw=true, -- trigger room transition in edges
	update = function(self) --player.update
		if self.fate then return end
		self.invul=max(self.invul-1,0)
		if self.knock==0 then
			arm_jump()
		end
		if self.knock==0 and jump_arm and ride and self.onground
		and ((btnp(4) or btnp(5)) or self.jbuf>0) then
		air=ride
		ride=nil
		end
		upd_plats()
		   self.dy+=self.g
		local locked=self.knock>0
		if locked then
		self.play="hurt"
		if self.ktx then
			local d=self.ktx-self.x
			if d!=0 then
				local s=d>0 and 1 or -1
				self.dx=s*min(2,abs(d))
				self.ax=0
			else
				self.dx=0
				self.ax=0
			end
		else
			self.dx=self.kdx
		end
		if self.hop then
			self.dy=-3
			self.hop=false
		end
		self.knock-=1
		if self.knock==0 then
			self.ktx=nil
		end
		else
		self.dx=0
		for cmd in all(read_plyr_cmds()) do
			cmd(self)
		end
		if jump_arm and self.onground and self.jbuf>0 then
			plyr_jump(self)
		end
		if self.jbuf>0 and not (btnp(4) or btnp(5)) then
			self.jbuf-=1
		end
	end
		local y0=self.y
		air_shift()
		   move_and_collide(self)
		stick_ride()
		stick_hold()
		try_board(y0)
		take_hearts(self)
		upd_ledges()
		if ride or hold or cmap(self, self.x, self.y+1) then
			self.onground=true
		if not ride then air=nil end
		else
			self.onground=false
		end
		if not locked then
		if not self.onground then
		 self.play="jump"
		elseif self.dx!=0 then
		 self.play="walk"
		else
		 self.play="idle"
		end
		end
		  animate(self)
		  end,
    draw = function(self) --player.draw
		if not self.fate and self.invul>0 and self.invul%8<4 then
			for c=1,15 do
				pal(c,8)
			end
		end
        spr(self.sp,self.x,self.y,2,2,self.dir==1,false)
		pal()
		pal(9,142,1)
    end
}

-->8
-- enemy --
enemy_kinds={
	[96]={
		sp=64,w=4,h=2,dmg=3,chase=true,push=true,
		anim={walk={fr=6,64,68}}
	},
	[76]={
		sp=72,w=2,h=2,dmg=2,chase=false,push=false,
		anim={walk={fr=6,72,74}}
	},
}

function sm_change(e,next_state)
	local sm=e.sm
	if sm.current==next_state then return end
	if sm.current and sm.current.exit then
		sm.current.exit(e)
	end
	sm.current=next_state
	if sm.current and sm.current.enter then
		sm.current.enter(e)
	end
end

function sm_update(e)
	local next_state=st_patrol
	if e.chase and enemy_vision(e) then
		next_state=st_chase
	end
	sm_change(e,next_state)
	e.sm.current.update(e)
end

function enemy_vision(e)
	if player.invul>0 or player.fate then return false end
	local ax,ay=e.x+e.sw*4,e.y+e.sh*4
	local px,py=player.x+8,player.y+9
	local dx=(px-ax)*e.dir
	local dy=py-ay
	if dx<0 or dx>64 or abs(dy)*8>dx*3 then
		return false
	end
	return not ray_blocked(ax,ay,px,py)
end

function ray_blocked(x0,y0,x1,y1)
	local n=flr(max(abs(x1-x0),abs(y1-y0)))
	if n<1 then return false end
	local sx,sy=(x1-x0)/n,(y1-y0)/n
	local hx,hy=flr(x0/8),flr(y0/8)
	local x,y=x0,y0
	for i=1,n do
		x+=sx
		y+=sy
		if i==n then x,y=x1,y1 end
		local cx,cy=flr(x/8),flr(y/8)
		if (cx!=hx or cy!=hy) and fget(mget(cx,cy),0) then
			local lx,ly=x-cx*8,y-cy*8
			if lx>1 and lx<7 and ly>1 and ly<7 then
				return true
			end
		end
	end
	return false
end

function enemy_blocked(e)
	return cmap(e,e.x+e.dir,e.y) or not cmap(e,e.x+e.dir*8,e.y+1)
end

function enemy_move(e,spd,hold)
	e.hx=e.dir==1 and e.sw*8-e.hw or 0
	e.dx=e.dir*spd
	if hold and enemy_blocked(e) then
		e.dx=0
	end
	e.dy+=e.g
	move_and_collide(e)
	if not hold and enemy_blocked(e) then
		e.dir*=-1
	end
	animate(e)
end

-- states
st_patrol={}

function st_patrol.update(e)
	enemy_move(e,0.75,false)
end

st_chase={}

function st_chase.enter(e)
	actions.notify("alert")
end

function st_chase.update(e)
	local pcx=player.x+8
	local ecx=e.x+e.sw*4
	if pcx<ecx then
		e.dir=-1
	elseif pcx>ecx then
		e.dir=1
	end
	enemy_move(e,2.5,true)
end

function hurt(o,n)
	if player.fate then return end
	if overlap(player.x+2,player.y+2,12,14,o.x,o.y,o.sw*8,o.sh*8)
	and player.invul<=0 then
		local before=player.hp
		player.hp-=n
		hearts_changed(before,player.hp,true)
		if player.hp<=0 then begin_death() return true end
		local s=1
		if player.x+8<o.x+o.sw*4 then s=-1 end
		player.ktx=nil
		player.kdx=2*s
		player.dx=player.kdx
		player.dy=-3
		player.hop=true
		player.knock=10
		player.jbuf=0
		player.invul=50
		player.play="hurt"
		ride=nil
		hold=nil
		air=nil
		actions.notify("hurt")
	end
end

function resolve_enemies()
	for e in all(ens) do
		if player.fate then return end
		if player.invul<=0
		and overlap(player.x+2,player.y+2,12,14,e.x,e.y,e.sw*8,e.sh*8) then
			if hurt(e,e.dmg) then return end
			if e.push then push_player(e) end
		end
	end
end

function push_player(e)
	ride=nil
	air=nil
	local leftx=e.x-14
	local rightx=e.x+e.sw*8-2
	local a,b=leftx,rightx
	if abs(rightx-player.x)<abs(leftx-player.x) then
		a,b=rightx,leftx
	end
	local exitx
	if not cmap(player,a,player.y) then
		exitx=a
	elseif not cmap(player,b,player.y) then
		exitx=b
	end
	player.ktx=nil
	player.kdx=0
	if exitx then
		local s=exitx<e.x and -1 or 1
		player.ktx=exitx+20*s
		local dist=abs(player.ktx-player.x)
		player.knock=flr((dist+1)/2)
		player.ax=0
	else
		player.knock=10
	end
	player.jbuf=0
end

function upd_rocks()
	local camx=mxmax-128
	local camy=mid(mymin, player.y-64, mymax-128)
	if t%30==0 then
		mk_rock(camx+rnd(120),camy-8)
	end
		for r in all(rocks) do
			if upd_rock(r,camy) then
				return
			end
		end
end

rock_anims={
	fall={fr=1,97},
	brk={fr=3,once=true,98,99}
}

function mk_rock(x,y)
	local r={
		x=x,
		y=y,
		spd=rnd(1)+1,
		sp=38, sw=1, sh=1,
		cm=true,
		hx=0,hy=0,hw=8,hh=8
	}

	anim_init(r,rock_anims,"fall")
	add(rocks,r)
end

function upd_rock(r,camy)
	if r.y>camy+128 then
		del(rocks,r)
		return
	end
	if r.play!="brk" then
		r.y+=r.spd
		if hurt(r,1) then
			return true
		end
		if cmap(r,r.x,r.y+1) then
			r.play="brk"
			actions.notify("brk")
		end
	end
	animate(r)
	if r.done then
		del(rocks,r)
	end
end
-->8
-- map --
-- world bounds --
function ledge_open(tx,ty)
	tx,ty=flr(tx),flr(ty)
	for l in all(ledges) do
		if not l.gone then
			for c in all(l.cells) do
				if c.x==tx and c.y==ty then
					return true
				end
			end
		end
	end
end

function map_solid(o,tx,ty)
	local tle=mget(tx,ty)
	if o==player and (tle==92 or ledge_open(tx,ty)) then
		return false
	end
	return fget(tle,0)
end

function cmap(o,x,y)
	x=x or o.x
	y=y or o.y

	local ct=false
	local cb=false

	-- colliding with map tiles --
	if o.cm then
		local bx=x+o.hx
		local by=y+o.hy
		local x1=bx/8
		local y1=by/8
		local x2=(bx+o.hw-1)/8
		local y2=(by+o.hh-1)/8

		ct=map_solid(o,x1,y1) or map_solid(o,x1,y2)
		or map_solid(o,x2,y2) or map_solid(o,x2,y1)
	end

-- colliding with world bounds --
	if o.cw then
		cb=x<mxmin or x+16>mxmax
		or y<mymin
	end

	return ct or cb
end

function tmap(o,f)
	local bx,by=o.x+o.hx,o.y+o.hy
	local x1,y1=bx/8,by/8
	local x2,y2=(bx+o.hw-1)/8,(by+o.hh-1)/8

	return fget(mget(x1,y1),f)
		or fget(mget(x1,y2),f)
		or fget(mget(x2,y1),f)
		or fget(mget(x2,y2),f)
end

-- move object o by its dx/dy, stop at walls --
function move_and_collide(o)
	o.ax+=o.dx
	o.ay+=o.dy
	local nx=flr(abs(o.ax))
	local ny=flr(abs(o.ay))
	local sx=sgn(o.ax)
	local sy=sgn(o.ay)
	o.ax-=nx*sx
	o.ay-=ny*sy

	for i=1,nx do
		if cmap(o,o.x+sx,o.y) then
			o.dx=0
			o.ax=0
			break
		end
		o.x+=sx
	end
	for i=1,ny do
		if cmap(o,o.x,o.y+sy) then
			o.dy=0
			o.ay=0
			break
		end
		o.y+=sy
	end
end

function upd_cam()
	cx=mid(mxmin,player.x-64,mxmax-128)
	cy=mid(mymin,player.y-64,mymax-128)
end

function mapcam()
	camera(cx+cam_shake(), cy)
end
-->8
-- controller
function cmd_lft(p)
	p.dx=-p.speed
	p.dir=0
end

function cmd_rght(p)
	p.dx=p.speed
	p.dir=1
end

function plyr_jump(p)
	p.dy=p.initaccel
	p.onground=false
	p.jbuf=0
	actions.notify("jump")
end

function cmd_jmp(p)
	if p.onground then
		plyr_jump(p)
	else
		p.jbuf=5
	end
end

binds={
	[0]=cmd_lft,
	[1]=cmd_rght
}

function arm_jump()
	if jump_arm then return end
	if not btn(4) and not btn(5) then
		jump_arm=true
	end
end

function read_plyr_cmds()
	local cmds={}
	for b=0,1 do
		if btn(b) then add(cmds,binds[b]) end
	end
	if jump_arm and (btnp(4) or btnp(5)) then
		add(cmds,cmd_jmp)
	end
	return cmds
end
-->8
--animations
anims={
	idle={fr=20,1,3},
	walk={fr=6,5,7,9},
	jump={fr=6,11,13},
	hurt={fr=10,32},
	hold={fr=20,next="die",32},
	die={fr=8,once=true,38,40,42},
	angel={fr=6,44,46}
}

function anim_init(o,set,name)
	o.anims=set
	o.play=name
	o.state=name
	o.animindex=1
	o.time=0
	o.done=false
end

function animate(o)
	local a=o.anims[o.state]
	if o.state!=o.play then
	 o.state=o.play
	 o.animindex=1
	 o.time=0
	 a=o.anims[o.state]
	elseif #a>1 or a.next or a.once then
	 o.time+=1
	 if o.time>=a.fr then
	  o.time=0
	  o.animindex=(o.animindex%#a)+1
	  if o.animindex==1 and a.next then
	   o.play=a.next
	   o.state=o.play
	   a=o.anims[o.state]
	  elseif o.animindex==1 and a.once then
		o.done=true
	  end
	 end
	end
	o.sp=a[o.animindex]
end
-->8
-- subscriber
actions = {
	subs={}
}

function actions.sub(event,fn)
	local list=actions.subs[event]
	if not list then
		list={}
		actions.subs[event]=list
	end
	add(list,fn)
end

function actions.unsub(event,fn)
	local list=actions.subs[event]
	if list then
		rem(list,fn)
	end
end

function actions.notify(event)
	local list=actions.subs[event]
	if not list then return end
	for fn in all(list) do
		fn(event)
	end
end
-->8
-- SFX observer
sfx_ids={
	jump=0,
	heal=1,
	hurt=2,
	brk=4,
	die=5,
	alert=6
}

function on_sfx(event)
	local id=sfx_ids[event]
	if id then
		sfx(id)
	end
end

function init_audio()
	actions.sub("jump",on_sfx)
	actions.sub("heal",on_sfx)
	actions.sub("hurt",on_sfx)
	actions.sub("brk",on_sfx)
	actions.sub("die",on_sfx)
	actions.sub("alert",on_sfx)
end

__gfx__
00000000000090000090000000000000000000000000009000900000000000900090000000000900090000000000000090000000000000009000000000000000
00000000000079000970000000009000009000000000007909790000000000790979000000000790979000000000009979099000000000997909900000000000
00700700000099999990000000007900097000000000099999990000000009999999000000009999999000000000019999979000000001999997900000000000
00077000000091999190000000009999999000000000019199990000000001919999000000001919999000000000019199990000000001919999000000000000
00077000000991999199000000009199919000000000019199990000000001919999000000001919999000000000199199990000000019919999000000000000
00700700000999717999000000099199919900000000177799999000000017779999900000017779999900000000777799999000000077779999900000000000
00000000000099777990000000099971799900070000777999999000000077799999900000077799999900000000077999999000000007799999900000000000
00000000000000999000000000009977799000770000000999000077000000099900000000000099900000000007700977000000000770097700000000000000
00000000000099979990000000799999999979770000007999900996000000799990007700000799990000000007997979900000000799797990007700000000
00000000000999777999000700779997999779970000007799909999000000779990099600000779990000000000097799900000000009779990999600000000
00000000000799777997007700000977799999990000077799979990000000779999999900009779999900000000007799900000000000779999999000000000
00000000000779777977099900000977799999990000077799779900000000779779999000007777999999000000007799990000000000779999990000000000
00000000000009999999999900000977799999900000009999990000000000999999990000000999999999700000009999999900000000999990000000000000
00000000000009909999999000000999999990000000009999000000000000099900000000000999999996600000000990999990000000099099000000000000
00000000000009909909990000000990990000000000079099600000000000099900000000000790996000000000000096096997000000009609600000000000
00000000000077707770000000007770777000000000076007600000000000777700000000007760076000000000000076076006000000007607600000000000
000000900090000000090009000000000009000900000000000000d000d00000000000d000d0000000000000000000000000007a7a000000000000a7a7000000
0000007909790000000790979000000000790079000000000000000d0d0d00000000000d0d0d0000000000000000000000006000006000000000600000600000
000009999999000000999999900000000999999900000000000000d0d0d00000000000d0d0d00000000000000000000000007600067600000000760006760000
000001919999000000191999900000000191999900000000000001d1dddd0000000001010d0d0000000000000000000000006666666600000000666666660000
000001911999000000191999900000000191999900000000000001d11ddd0000000000d010d00000000000d00000000000006616661600000000661666160000
00001777999990000177799999000000177799999000000000001777ddddd000000007070d0d0000000000070000000000066616661660000006661666166000
00007788999990770777999999000000777999999000000000007788ddddd07000007080d0d0d070000000800000d00000066667176660000006666717666000
0000000999900997000099900000000000099999970000000000000dddd00d070000000d0d000d07000000000000000007706667776607700000666777660000
000077077997799900097999997000000097999997000000000070007dd770d00000700070d070d0000000000000000000777666666777000000766666670000
00007977799979900099779909700770099779900000000000000d077ddd0d0000000d070d0d0d0000000d00000d000007777666766777700077766676677770
000000777999999007907799000999600797799000999700000000707dddd0d00000007070d0d0d0000000000000d00000077667776770700777766777677770
00000077999999000770779999999900077779999999977000000007dddd0d00000000070d0d0d00000000000000000000777667776777707777766777676667
000009999999900000000999999990000000999999999700000000d0d0d0d000000000d0d0d0d000000000000000000000000667776066700070766777666600
00077999999000000000099990000000000099999000000000070d0d0d00000000070d0d0d00000000070d000d00000000000666666666000000066666666000
00076977990000000000096099600000000096099600000000006070d000000000006070d000000000000000d000000000000066666600000000006666660000
00000076900000000000076007600000000076007600000000000006000000000000000600000000000000000000000000000000000000000000000000000000
000000000000000000000000006660000060000000600000000000000666600000000000000000000000000000000000ffffffff0010101100b00b0044422444
006000000600000000000000066566000066000006660000066000000666650000060000006600000000000000000000f2ffff2f010101110b3b3bb0442b4244
006600000660000000600000065005600666688666660000666006600000666000660000006660000000000000000000ffffffff00101011b3b3b3b3b2bbb424
066660006660000066600060000006600666666666666066666066600000065000566000666560000000600000060000ffffffff01010111b333333bb33333bb
066688666666066666606660000005606666666666666666666666566600066606566666665560000006600000660000ffffffff001010113333333b0333333b
6666666666666566666666666600066066866666866665666666656666000066066666666665605000566000666500002f2ff2f2010101113333343300303030
68666668666665666666666566600660668866688666656666666666666000666666666666666555005666666655005022222222001010113423424300000000
6886668866655666665666566660066066666666666556666666666666600066666866668666655506666666666565552f2ff2f2010101114442244400000000
666666666665666665666666666666600666666666656666666566656666066566666666666666660666666666666666bbbbbbbbbbbbbbbbbbbbbbbb44422444
666666666655666666666666656666000668686866556666665666566666665066667667666656666668666686665666bb3b33b33b3b333b3b3bb33344244244
06868686655666656666666656666600006686866556666666666666666666500666888866665665666666666666656633333434443434344434b43442444424
00686866566666566656666666665000000666665666666666666666666665000666666666665650666676676666656643434443444444444444444442422424
00066666555555566555566666655000000000000066666666666666666660000666666666656500666688886666656504444440044444400444444042422424
00000005555500666000066665555500000000000666650555500556666660000066666666560000666666666666565000000000000000000000000042444424
00000065555000566500666650555550000000066666500555005555066666000066666665500000066666666666650000000000000000000000000044244244
00000655500000055005555500005555000000665655000055055550006666000000555550000000005555555555500000000000000000000000000044422444
8f8ff8f8006666000066660000666600000bbb0bb0bbb000b0bbb000000000000007777777777700000000009999999922222222666666660000000066666666
f8ffff8f06666660006666000060000000b3b3b3b3b3bb00b3aabb00000000000077776767777770000000009999999944449444565656650555555066665666
8f8ff8f8666666616006606160000061033b3b3b3b3b3bb03eeeebb000000000077776777677777777000000999999994449a944656565565555555565666656
ffffffff666616616660066166000001033333333333b3b03eeee3b0000077777777777777777777777700009999999944449444565656555565565566666666
ffffffff6611666166100661000060613333333333333b3b3aaeaa3b00077777777777777777777777777700d999999d22222222055555505656565666566666
8f8ff8f8661666616606606160000001333333333333b3bbeeeeeeeb00777777777777777777777777777770dd9999dd44444444000000006565656566666566
888888880666661100666611006000013333333333333b3beeeeeeeb07777777777777777777777777777777ddd99ddd44444444000000006656665666656666
8f8ff8f800661100006611000060010003333333333333303ee3ee3077777777777777777777777777777777dddddddd44444444000000005666566556666666
00000000000000000000000000202020000000000000000000088200777776767777777777776776777777770000000000000000bbbbbbbb0bbbb0b0000bb000
07700770878087780770077027720770077007700090090000088200777767776777777777767777677777670077770000077000333333333030333300300300
78877887780778077207720770077007700770070999999000088200767777777777777777777777777777760788887000077000666566560565606600065000
78888887708080877020202720000002700000070919919000088200677777777777777777777777777767660788887000077000656665665606056050000500
78888887780808077202020770000007700000070999999000088200067677777777777777777777777776600788887000077000065666600060605000606000
07888870878080780720207007000070070000707771177700000000006777676777677767776777676766000078870000077000000000000000000000000000
00788700007807800072070020700702007007000777777000088200000666767676767676767676767660000078870000077000000000000000000000000000
00077000080778000007700002072020000770000000000000088200000006666666666666666666666600000007700000077000000000000000000000000000
f4000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000f5f500000000000000000000f6f6f6f6f600000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000e4e4e4e4e4e4e4e40000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000700f5f500000000000000000000d6f6f6f6f600000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000f5f5f5f5f5f5f5f50000d7d70000d5d5d50000000000
0000000000000000000000000000000000e5e500000000000000000000c500f5f50000000000000000000000d6f6f6f60000d7d7000000000000000000000000
00000000000000000000d5d5d50000000000c5c5c5c50000e4e400000000000000000000000000000000f5f5f5f5f5f5f5f50000000000000000000000000000
000000000000000000000000d7d70000000000000000d7000000d700000000f5f5000000000000000000000000d6d6d600c40000000000000000000000000000
0000000000000000e4e40000000000000000000000000000f5f50000000000000000000000000000e5e5f5f5f5f5f5f5f5f50000000000000000060000000000
00000000000000000000000000000006000000000000000000000000000000f5f50000000000000000000000000000d400000000000000000000000000000000
000000000000e4e4f5f5000006000000000000000000e4e4f5f500d5d5d5000000000000c5c5c5c50000f5f5f5f5f5f5f5f50000e4e4e4000000000000000000
0000000000000000e5e5000000000000000000000000000000000000000000f5f50000000000000000000000000000d4e6e6e6e6e6e6e60000d7d70000000000
00000000e4e4f5f5f5f5000000000000000000000000f5f5f5f500000000000000000000000000000000f5f5f5f5f5f5f5f50000f5f5f5e4e4e4e4e4e4e4e4e4
e4e4e4e4e4e4000000000000e4e4e4e4e4e4e4e4e4e4e4e4e4e4e4e4e4e4e4f5f500e500d50000000000e6e6e6e6e6e6f6f6f6d6d6d6d6000000000000000000
e4e4e4e4f5f5f5f5f5f5e4e4e4e4e4e4e4e4e4e4e4e4f5f5f5f500000000000000000000000000000000f5f5f5f5f5f5f5f50000f5f5f5f5f5f5f5f5f5f5f5f5
f5f5f5f5f5f5000000000000f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5000000000000000000f6f6f6f6f6f6f6f6d60000000000000000000000d7d7
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000d6d60000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000d7d700000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000d7d70000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000e6
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000d7d700000000000000000000e6f6
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000f6f6
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000f6f6
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000e6e6e6e6e6e6e6e6000000000000f6f6
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000f6f6f6f6f6f6f6d600d7d7000000f6f6
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000f6f6f6d6d6d6d600000000000000f6f6
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000f6f6d600000000000000000000e6f6f6
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000d6d60000000000000000000000f6f6f6
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000e6f6f6f6
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000e6f6f6f6f6
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000e6e6e6e6e6e6e6e6e6e6e6f6f6f6f6f6
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6
__gff__
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000020101000000000000000000000000000101010000000000000000000000000000010100000000000000000000000000050101
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000005f5f5f5f0000000000000000000000006b6b6b6b
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000005f5f5f5f0000000000000000000000006c6c6c6c
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000005f5f5f5f0000000000000000000000006c6c6c6c
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000005f5f5f5f0000000000000000000000006c4d6c6c
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000070005f5f5f5f0000000000000000000000006c4d6c6c
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000004e4e4e4e5f5f5f5f0000000000000000006e6e6e6e6e6e6e
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000005d5d0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000004f5f5f5f5f5f5f5f0000000000007d7d006d6d6d6d6d6d6d
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000004e4e4e00004c000000000000000000000000000000000000000000000000000000000000005c5c5c000000000000000000004f5f5f5f5f5f5f00000000000000000000000000000000
000000000000000000000000000000000000000000005c5c000000000000000000000000000000000000000000000000000000000000005f5f5f00000000000000000000000000000000000000000000000000000000000000000000000000000000005e5e00000000004f5f5f5f5f5f00000000000000000000000000000000
0000000000000000000000000000000000000000000000000000005c5c5c00000000000000000000000000000000000000000000004e4e5f5f5f4e4e4e4e4e4e4e4e4e4e00000000000000000000000000000000005d5d00000000000000000000000000000000000000004f5f5f5f5f0000007d000000000000000000000000
0000000000000000000000000000000000005c5c0000004c00000000000000000000000000005c5c00005e5e0000000000000000005f5f5f5f5f5f5f5f5f5f5f5f5f5f5f000000000000000000000000000000000000000000000000000000000000000000000000000000004f4f4f4f00000000000000000000000000000000
0000000000000000000000004e4e4e4e000000000000000000000000000000000000000000000000000000000000000000000000005f5f5f5f5f5f5f5f5f5f5f5f5f5f5f4e4e4e0000000000004c000000004e4e0000000000000000000000004c00000000000000000000000000004d0000000000007d000000000000000000
000000000000000000004e4e5f5f5f5f000000000000000000000000000000000000000000000000000000000000000000000000005f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f00000000000000000000005f5f0000000000000000000000000000000000000000000000000000004d000000000000000000007d0000000000
00000000000000004e4e5f5f5f5f5f5f00000000004e4e4e4e4e4e4e4e4e4e0000004e4e4e4e0000000000000000000000000000005f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f4e4e4e4e4e4e4e4e4e4e4e5f5f00004e4e4e4e4e4e4e4e4e4e4e000000004e4e4e4e4e4e4e4e4e4e4e00000000000000000000000000007d7d
0000000000004e4e5f5f5f5f5f5f5f5f00000000005f5f5f5f5f5f5f5f5f5f0000005f5f5f5f00000000000000000000004e4e4e4e5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f00005f5f5f5f5f5f5f5f5f5f5f000000005f5f5f5f5f5f5f5f5f5f5f00000000000000000000000000000000
4e4e4e4e4e4e5f5f5f5f5f5f5f5f5f5f00000000005f5f5f5f5f5f5f5f5f5f0000005f5f5f5f005c0000005c0000005c005f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f00005f5f5f5f5f5f5f5f5f5f5f000000005f5f5f5f5f5f5f5f5f5f5f00000000000060000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000006e00000000000000006e00007d000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000006f6e6e6e6e6e6e6e6e6f000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000006d6d6d6d6d6d6d6d6d6d000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000005e5e
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000700000000000000000007d7d00000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000006e6e0000000000000000000000000000
5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f4f4f4f4f4f4f4f4f4f4f4f4f5f5f5f5f5f5f5f5f5f6f6f6f6f6f6f6f6f6f6f0000000000000000000000000000
5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f4f4f4f4f4f4f4f4f4f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f4f4f4f4f4f4f4f5f5f5f5f5f5f5f5f5f5f5f5f4f0000000000000000000000004f5f5f5f5f5f5f5f5f6f6f6f6f6f6f6f6f6f6f000000007d7d0000000000000000
5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f4f5f5f4f4f4f4f4f5f5f0060000000000000005f5f4f4f4f4f4f4f4f4f4f4f4f4f4f4f5f5f5f5f5f5f5f5f5f000000000000005f5f5f5f5f5f5f5f5f5f5f4f00000000000000000000000000004f4f4f4f4f5f5f5f6f6f6f6f6f6f6f6f6f6f0000000000000000000000000000
5f5f5f5f4f4f4f4f5f5f5f5f5f5f5f5f5f5f5f005f5f00000000005f5f0000000000000000005f5f00000000000000000000000000004f5f5f5f5f5f5f5f5f004c00000000005f5f5f5f5f5f5f5f5f5f4f00000000000000000000000000000000000000004f4f5f6f6f6f6f6f6f6f6f6f6f0000000000000000000000000000
5f5f4f4f000000004f5f5f5f5f4f4f4f5f5f5f004f4f00000000004f5f4e4e4e4e4e4e4e4e4e5f4f0000000000000000000000000000004f5f5f5f5f5f5f5f000000000000005f5f5f4f4f4f4f4f4f4f0000000000004c000000000000000000000000000000004f6d6f6f6f6f6f6f6f6f6d0000000000000000007d7d000000
5f5f000000000000004f4f4f4f0000004f4f4f0000000000000000004f4f4f4f4f4f4f4f4f4f4f00000000000000000000000000000000004f4f4f4f4f4f5f4e4e4e4e4e4e4e5f5f4f00000000000000000000000000000000000000000000000000000000000000006d6f6f6f6f6f6f6d000000000000000000000000000000
5f4f0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000004f4f4f4f4f4f4f4f4f4f000000000000000000000000004e4e4e4e4e4e4e4e4e4e4e4e0000000000000000006f6f6f6f6f6f00000000000000000000000000000000
5f000000000000000000000000000000000000000000000000000000000000000000000000000000000000004c000000000000000000000000000000000000000000000000000000000000000000000000000000004f4f4f4f4f4f4f4f4f4f5f5f0000000000000000006d6f6f6f6f6f000000000000007d7d00000000000000
__sfx__
9901000008710097100e7001770017710177101a700177001e7101e71023700237002370000700007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700
6f04000030534325342a5042d5042d5342e5343b5043450434534355343b5043f5043f5043f5043b5043f5040f5040f5040f5040f5040f5040f5040f5040f5043f504315043350436504385043a5043c5040d504
0f03000029750166101d7001575008610117000875008610037500361000700197001970019700197001970017700177001770017700177001770017700177001c7001c7001c7001c7001c7001c7001c7001c700
4e0400002160201612137120c602016120b7120460202602026022860225602256022160225602256022560225602286022860225602256022560228602256022860228602286022560228602286022860228602
d102000008610056100461001610006100d6000d6001b6001d6001f600206002060020600186001a6001d60000600006000060000600006000060000600006000060000600006000060000600006000060000600
930400003e6623c6623a6623866236662356523365231652306522f6522d6522c6522a6522865227652256522465222652216521f6521d6521b652186521665213652106520d6520a65208652066520465201652
270200000d4600d76010460107601346013760164601676019460197601c4601c7601f4601f76022460227603170035700387003a70039700397003a7003b7003d7003e7003f7000070000700007000070000700
01140020152451522515215152451522515215152451522510215102451022510215102451021510245102150e2450e2250e2150e2450e2250e2150e2450e2251021510245102251021510245102151024510215
011400202572025720257202572021720217202172021720207202072020720207201c7201c7201c7201c7201e7201e7201e7201e7201a7201a7201a7201a7202072020720207202072023720237202372023720
9f140020253302532025300213302132021310213302131023330233202330020330203202031020330203102133021320213001e3301e3201e3101e3301e3102333023320233002033020320203102033020310
011400002d0302d0102d0302d0102f0302f0102d0302d0102c0302c010280302801028030280102503025010260302601028030280102a0302a010260302601028030280102c0302c01028030280102f0302f010
0114000021554215121c5521c5121a5521a5121c5521c512195521951220552205121e5521e512205522051221552215121c5521c5121a5521a5121c5521c5121c5521c512235522351221552215122355223515
011400002155021510215502151025550255102555025510205502051020550205102355023510235502351021550215101e5501e5101a5501a51021550215101c5501c510205502355023510205502355023510
79140000077400773007720077100974009710097400971006740067300672006710027400271002740027100b7400b7300b7200b7100d7400d7100d7400d7100974009730097200971006740067100674006710
a91400002b7222b7122b7122b7122d7222d7122d7122d7122a7222a7122a7122a712267222671226712267122f7222f7122f7122f712317223171231712317122d7222d7122d7122d7122a7222a7122a7122a712
0914000013742137101a7421a71015740197401c7421c710127401574015710197001a7401774017720177101774217710137421371019742197101c7421c7101274212710157421571017742177101274212710
091400001374013720137102370010740107201071019700127401272012710207000e7400e7200e710217001774017720177101e700157401572015710207001274012720127101c7000e7400e7101074010710
a91400001f7221f7121f7221f712217222171221722217121e7221e7121e7221e7121a7221a7121a7221a7122372223712237222371225722257122572225712217222171221722217121e7221e7121e7221e712
01100000180231a0231800035200190231a0230e61510645180230c600180003f100190231a0232560034200180231a0231800026000190231a0230e6151064518023301001800033100190231a0232560034200
451000000005000010010500101002050020100400004000000500001001050010100205002010040500401000050000100105001010020500201004000040000005000010010500101002050020100405004010
7710000000505005050050500505005050050500505005050050500505005050050500505005053d5003d50000505005050050500505005050050519555195553d500195550050519555195553d5000d5553d500
__music__
00 47074949
00 47070844
00 47070809
03 4707090a
00 470d494a
00 470d0e4c
01 470d0e10
00 470d0e10
02 480d110f
03 41121314

