module node;

import std.stdio;
import std.conv : to;
import std.traits;
import std.string : toLower;
import gtk.MainWindow;
import gtk.Widget;
import gtk.Layout;
import gtk.Image;
import gdk.RGBA;
import gdk.Cairo;
import cairo.Context;
import cairo.ImageSurface;
import cairo.Pattern;
import gdk.Pixbuf;
import cairo.Surface;
import material;
import resource;

public import vect;

enum XMacro : string{
	Right="ALIGN_RIGHT",
	Left="ALIGN_LEFT",
	Center="ALIGN_CENTER"
}
enum YMacro : string{
	Top="ALIGN_TOP",
	Bottom="ALIGN_BOTTOM",
	Center="ALIGN_CENTER"
}
enum WidthMacro : string{
	Parent="PARENT_WIDTH",
	Dynamic="DYNAMIC"
}
enum HeightMacro : string{
	Parent="PARENT_HEIGHT",
	Dynamic="DYNAMIC"
}

//#######################################################################################
//#######################################################################################
//#######################################################################################
class Node {
	this(string name_, Node parent_, in Vect position_=Vect(0,0), in Vect size_=Vect(0,0)) {

		name = name_;
		position = position_;
		size = size_;

		parent = parent_;

		container = new Layout(null, null);
		container.setSizeRequest(size.x, size.y);
		container.setHscrollPolicy(GtkScrollablePolicy.MINIMUM);
		container.setVscrollPolicy(GtkScrollablePolicy.MINIMUM);
		container.setName(name);
	
		if(parent !is null){
			parent.children ~= this;
			parent.container.put(container, position.x, position.y);
		}
	}

	string name;
	Node parent;
	Vect position;
	Vect size;

	Node[] children;

	Layout container;

	@property Vect absposition(){
		Vect ret = Vect(0,0);
		Node p = this;
		while(p !is null){
			ret+=p.position;
			p = parent;
		}
		return ret;
	}
}


//#######################################################################################
//#######################################################################################
//#######################################################################################
class UIScene : Node {
	static Get(){
		return m_inst;
	}


	this(ref string[string] attributes){
		string name;
		Vect size;

		foreach(key ; attributes.byKey){
			auto value = attributes[key];
			switch(key){
				case "name": 
					name=value;
					attributes.remove(key);
					break;
				case "width":
					size.x=value.to!int;
					attributes.remove(key);
					break;
				case "height":
					size.y=value.to!int;
					attributes.remove(key);
					break;
				case "OnAdd": 
					attributes.remove(key);
					break;//TODO impl

				case "x","y": //position should always be 0
					attributes.remove(key);
					break;
				case "draggable","fadein","fadeout","scriptloadable","priority","backoutkey": //Ignored attr
					attributes.remove(key);
					break;

				default: break;
			}
		}

		super(name, null, Vect(0,0), size);

		//Create window
		window = new MainWindow(name);
		window.setIconFromFile("res/icon.ico");

		//Forbid resize
		window.setDefaultSize(size.x, size.y);
		auto geom = GdkGeometry(size.x, size.y, size.x, size.y);
		window.setGeometryHints(null, &geom, GdkWindowHints.MIN_SIZE|GdkWindowHints.MAX_SIZE);

		//window background
		auto pbuf = Resource.FindFileRes!Material("bg.tga");
		auto surface = ImageSurface.create(CairoFormat.ARGB32, pbuf.getWidth, pbuf.getHeight);
		auto ctx = Context.create(surface);
		setSourcePixbuf(ctx, pbuf, 0, 0);
		ctx.paint();
		
		auto fill = Pattern.createForSurface(surface);
		fill.setExtend(CairoExtend.REPEAT);
		container.addOnDraw((Scoped!Context c, Widget w){
			c.setSource(fill);
			c.paint();

			c.identityMatrix();
			return false;
		});
		
		window.add(container);

		//Register instance
		m_inst = this;
	}

	MainWindow window;

	private __gshared UIScene m_inst;
}


//#######################################################################################
//#######################################################################################
//#######################################################################################
class UIPane : Node {
	this(Node parent, ref string[string] attributes){
		string name;
		Vect pos, size;

		foreach(key ; attributes.byKey){
			auto value = attributes[key];
			switch(key){
				case "name": 
					name=value;
					attributes.remove(key);
					break;
				case "width": 
					switch(value){
						case WidthMacro.Parent: size.x=parent.size.x; break;
						case WidthMacro.Dynamic: writeln("Warning: Dynamic is not handled"); size.x=10; break;
						default: size.x=value.to!int; break;
					}
					attributes.remove(key);
					break;
				case "height": 
					switch(value){
						case HeightMacro.Parent: size.y=parent.size.y; break;
						case HeightMacro.Dynamic: writeln("Warning: Dynamic is not handled"); size.y=10; break;
						default: size.y=value.to!int; break;
					}
					attributes.remove(key);
					break;

				case "OnAdd": break;//TODO impl

				case "draggable","fadein","fadeout","scriptloadable","priority","backoutkey": break;//Ignored attr

				default: break;
			}
		}

		if("x" in attributes){
			switch(attributes["x"]){
				case XMacro.Left: pos.x=0; break;
				case XMacro.Right: pos.x=parent.size.x-size.x; break;
				case XMacro.Center: pos.x=parent.size.x/2-size.x/2; break;
				default: pos.x=attributes["x"].to!int; break;
			}
			attributes.remove("x");
		}
		if("y" in attributes){
			switch(attributes["y"]){
				case YMacro.Top: pos.y=0; break;
				case YMacro.Bottom: pos.y=parent.size.y-size.y; break;
				case YMacro.Center: pos.y=parent.size.y/2-size.y/2; break;
				default: pos.y=attributes["y"].to!int; break;
			}
			attributes.remove("y");
		}
		super(name, parent, pos, size);
		//container.overrideBackgroundColor(GtkStateFlags.NORMAL, new RGBA(0,1,0,1));
	}
}

//#######################################################################################
//#######################################################################################
//#######################################################################################
class UIFrame : UIPane {
	this(Node parent, ref string[string] attributes){
		Material mfill;//, mtopleft, mtop, mtopright, mleft, mright, mbottomleft, mbottom, mbottomright;
		Material[8] mborders;

		foreach(key ; attributes.byKey){
			auto value = attributes[key];
			switch(key){
				case "fillstyle":
					switch(value){
						case FillStyle.Stretch: fillstyle=FillStyle.Stretch; break;
						case FillStyle.Tile: fillstyle=FillStyle.Tile; break;
						default: throw new Exception("Unknown fillstyle "~value);
					}
					attributes.remove(key);
					break;
				case "fill": 
					mfill = Resource.FindFileRes!Material(value.toLower);
					attributes.remove(key);
					break;
				case "topleft": 
					mborders[0] = Resource.FindFileRes!Material(value.toLower);
					attributes.remove(key);
					break;
				case "top": 
					mborders[1] = Resource.FindFileRes!Material(value.toLower);
					attributes.remove(key);
					break;
				case "topright": 
					mborders[2] = Resource.FindFileRes!Material(value.toLower);
					attributes.remove(key);
					break;
				case "left": 
					mborders[3] = Resource.FindFileRes!Material(value.toLower);
					attributes.remove(key);
					break;
				case "right": 
					mborders[4] = Resource.FindFileRes!Material(value.toLower);
					attributes.remove(key);
					break;
				case "bottomleft": 
					mborders[5] = Resource.FindFileRes!Material(value.toLower);
					attributes.remove(key);
					break;
				case "bottom": 
					mborders[6] = Resource.FindFileRes!Material(value.toLower);
					attributes.remove(key);
					break;
				case "bottomright": 
					mborders[7] = Resource.FindFileRes!Material(value.toLower);
					attributes.remove(key);
					break;
				case "border": 
					border = value.to!uint;
					attributes.remove(key);
					break;
				
				default: break;
			}
		}

		//UIframe specific
		if("width" !in attributes)
			attributes["width"] = "PARENT_WIDTH";
		if("height" !in attributes)
			attributes["height"] = "PARENT_HEIGHT";

		super(parent, attributes);

		fillsize = size-2*border;
		if(mfill !is null){

			//Load surface for pattern
			Pixbuf pbuf = mfill;
			if(fillstyle == FillStyle.Stretch)
				pbuf = pbuf.scaleSimple(fillsize.x,fillsize.y,GdkInterpType.BILINEAR);

			auto surface = ImageSurface.create(CairoFormat.ARGB32, pbuf.getWidth, pbuf.getHeight);
			auto ctx = Context.create(surface);
			setSourcePixbuf(ctx, pbuf, 0, 0);
			ctx.paint();

			//Pattern
			fill = Pattern.createForSurface(surface);

			if(fillstyle == FillStyle.Tile)
				fill.setExtend(CairoExtend.REPEAT);
			else
				fill.setExtend(CairoExtend.NONE);
		}

		foreach(index, ref mat ; mborders){
			if(mat !is null){
				auto bordergeom = GetBorderGeometry(index);
				Pixbuf pbuf = mat.scaleSimple(bordergeom.width,bordergeom.height,GdkInterpType.BILINEAR);
				auto surface = ImageSurface.create(CairoFormat.ARGB32, bordergeom.width, bordergeom.height);
				auto ctx = Context.create(surface);
				setSourcePixbuf(ctx, pbuf, 0, 0);
				ctx.paint();

				//Pattern
				borders[index] = Pattern.createForSurface(surface);
			}
		}


		container.addOnDraw((Scoped!Context c, Widget w){

			foreach(index, ref pattern ; borders){
				if(pattern !is null){
					c.save;

					auto bordergeom = GetBorderGeometry(index);
					c.translate(bordergeom.x, bordergeom.y);
					c.setSource(pattern);
					c.rectangle(0, 0, bordergeom.width, bordergeom.height);
					c.clip();
					c.paintWithAlpha(1.0);//todo: handle alpha

					c.restore;
				}
			}
			

			if(fill !is null){
				c.save;

				//todo: handle fillstyle=center here?
				c.translate(border, border);
				c.setSource(fill);
				c.rectangle(0, 0, fillsize.x, fillsize.y);
				c.clip();
				c.paintWithAlpha(1.0);//todo: handle alpha

				c.restore;
			}
			c.identityMatrix();
			return false;
		});
	}
	


	


	enum FillStyle : string{
		Stretch="stretch",
		Tile="tile",
		Center="center"
	}

	Pattern fill;
	FillStyle fillstyle = FillStyle.Stretch;
	Vect fillsize;

	uint border = 0;
	Pattern[8] borders;

private:
	auto GetBorderGeometry(size_t borderIndex){
		import std.typecons: Tuple;
		alias data = Tuple!(int,"x", int,"y", int,"width", int,"height");
		switch(borderIndex){
			case 0: return data(0,0,                          border,border);
			case 1: return data(border,0,                     fillsize.x,border);
			case 2: return data(size.x-border,0,              border,border);

			case 3: return data(0,border,                     border,fillsize.y);
			case 4: return data(size.x-border,border,         border,fillsize.y);

			case 5: return data(0, size.y-border,             border,border);
			case 6: return data(border, size.y-border,        fillsize.x,border);
			case 7: return data(size.x-border,size.y-border,  border,border);
			default: assert(0);
		}
	}
}


//#######################################################################################
//#######################################################################################
//#######################################################################################
class UIIcon : UIPane {
	this(Node parent, ref string[string] attributes){
		Material mimg;

		foreach(key ; attributes.byKey){
			auto value = attributes[key];
			switch(key){
				case "img": 
					mimg = Resource.FindFileRes!Material(value.toLower);
					attributes.remove(key);
					break;
				default: break;
			}
		}

		super(parent, attributes);

		if(mimg !is null){

			//Load surface for pattern
			Pixbuf pbuf = mimg.scaleSimple(size.x,size.y,GdkInterpType.BILINEAR);

			auto surface = ImageSurface.create(CairoFormat.ARGB32, pbuf.getWidth, pbuf.getHeight);
			auto ctx = Context.create(surface);
			setSourcePixbuf(ctx, pbuf, 0, 0);
			ctx.paint();

			//Pattern
			img = Pattern.createForSurface(surface);
			img.setExtend(CairoExtend.NONE);
		}



		container.addOnDraw((Scoped!Context c, Widget w){
			if(img !is null){
				c.save;

				c.setSource(img);
				c.paintWithAlpha(1.0);//todo: handle alpha

				c.restore;
			}
			c.identityMatrix();
			return false;
		});
	}

	Pattern img;
}