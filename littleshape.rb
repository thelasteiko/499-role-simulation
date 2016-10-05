=begin
The shape classes pair with constraints and themes to draw
a shape on the canvas. The shape is part of a component that
can have child components all with their own shape.
=end

$DPI = 118
$FONT_WIDTH_RATIO = 0.6
  
# Defines bounds for a shape.
# @author Melinda Robertson
# @version 20160606
class Constraint
  attr_accessor :x   #top left
  attr_accessor :y   #top left
  attr_accessor :x1  #bottom right
  attr_accessor :y1  #bottom right
  attr_accessor :w   #width
  attr_accessor :h   #height
  attr_accessor :r   #radius
  attr_accessor :xc  #center x
  attr_accessor :yc  #center y
  attr_accessor :fit #whether the object can grow and shrink
  # Creates a constraint object.
  # @param x [Fixnum] is the top left x coordinate.
  # @param y [Fixnum] is the top left y coordinate.
  # @param w [Fixnum] is the width.
  # @param h [Fixnum] is the height.
  def initialize (x=0, y=0, w=0, h=0, fit=false)
    @x = x
    @y = y
    @w = w
    @h = h
    if w == h 
      @r = w/2
      @xc = x+@r
      @yc = y+@r
    else
      @r = 0
      @xc = 0
      @yc = 0
    end
    @x1 = x+w
    @y1 = y+h
    @fit = fit
  end
  # Creates a deep copy of the object.
  def clone
    c = Constraint.new(@x,@y,@w,@h,@fit)
    return c
  end
  # Sets the x and y values and re-calculates derived values.
  # @param constraint [Contraint] holds the new x and y values.
  def set(constraint)
    @x = constraint.x
    @y = constraint.y
    if @r > 0
      @xc = @x+@r
      @yc = @y+@r
    end
    @x1 = @x+@w
    @x2 = @x+@w
  end
  def set_xy(x, y)
    @x = x
    @y = y
    @x1 = x+@w
    @y1 = y+@h
  end
  def set_wh(w, h)
    @w = w
    @h = h
    @x1 = @x+w
    @y1 = @y+h
  end
  # Returns a string representation of the object.
  def to_s
    str = "{x:" + @x.to_s + ",y:" + @y.to_s + ",x1:" + @x1.to_s + ",y1:" + @y1.to_s + ",w:"
    str += @w.to_s + ",h:" + @h.to_s + ",r:" + @r.to_s + "," + @xc.to_s + "," + @yc.to_s + "}"
    return str
  end
end

#To draw the component I need to have a shape to draw.
#Fox.FXRGB(255, 235, 205)
#use the fx ruby rgb colors

# Colors, size and style related to appearance of a shape.
class Theme
  #http://www.rubydoc.info/gems/fxruby/Fox/FXColor
  attr_accessor :stroke_color #border
  attr_accessor :fill_color   #inside shape
  attr_accessor :highlight_color #when selected
  #string representing style: "dash", "dot"
  attr_accessor :border_style
  #pixel point size of border
  attr_accessor :border_size
  #http://www.rubydoc.info/gems/fxruby/Fox/FXFont
  attr_accessor :font_type
  attr_accessor :font_size
  attr_accessor :font_color
  attr_accessor :font_weight
  attr_accessor :corner_style
  
  #Creates the default theme.
  def initialize
    @stroke_color = nil #Fox.FXRGB(0,0,0)
    @fill_color = nil #Fox.FXRGB(255,255,255)
    @highlight_color = nil #Fox.FXRGB(55,55,55)
    @border_style = "solid"
    @border_size = 2
    #@font = FXFont.new(getApp(), "times", 36, FONTWEIGHT_NORMAL)
    @font_type = "modern"
    @font_size = 12
    @font_color = nil #Fox.FXRGB(0,0,0)
    @font_weight = FONTWEIGHT_NORMAL
    @corner_style = "sharp"
  end
  
  # Returns a FXFont instance.
  # @param app [FXApp] is the parent application.
  def font(app=nil)
    return @font if @font
    @font = FXFont.new(app, @font_type, @font_size, @font_weight)
    @font.create
    return @font
  end
  # Creates a deep copy of the object.
  def clone
    theme = Theme.new
    theme.stroke_color = @stroke_color if @stroke_color
    theme.fill_color = @fill_color if @fill_color
    theme.highlight_color = @highlight_color if @highlight_color
    theme.border_style = @border_style.clone if @border_style
    theme.border_size = @border_size if @border_size
    theme.font_type = @font_type.clone if @font_type
    theme.font_size = @font_size if @font_size
    theme.font_weight = @font_weight if @font_weight
    theme.font_color = @font_color if @font_color
    theme.corner_style = @corner_style.clone if @corner_style
    return theme
  end
  # Creates a string representation of the object.
  def to_s
    str = "{SC:" + (@stroke_color ? @stroke_color.to_s : "*") + ","
    str += "FC:" + (@fill_color ? @fill_color.to_s : "*") + ","
    str += "HC:" + (@highlight_color ? @highlight_color.to_s : "*") + ","
    str += "BST:" + (@border_style ? @border_style.to_s : "*") + ","
    str += "BSI:" + (@border_size ? @border_size.to_s : "*")
    return str
  end
end

# The shape module holds classes that represent different
# shapes.
module LittleShape
  class Shape
    attr_accessor :constraint #shape boundaries
    attr_accessor :theme      #color and style
    # Creates a shape object.
    # @param constraint [Constraint] lists the numerical size parameters.
    # @param theme [Theme] lists the color and style parameters.  
    def initialize (constraint=nil, theme=nil)
      c = constraint
      t = theme
      if not c
        c = Constraint.new
      end
      if not t
        t = Theme.new
      end
      @constraint = c
      @theme = t
    end
    def clone
      Shape.new(@constraint.clone, @theme.clone)
    end
  end
  class Rectangle < LittleShape::Shape
    def initialize (constraint=Constraint.new, theme=nil, content=nil)
      super(constraint,theme)
      @content = content
      if @content
        py = ((@theme.font_size * $DPI) / 72) #height
        #60% of font size?
        px = ((@theme.font_size * $DPI) / 72) * @content.size * $FONT_WIDTH_RATIO
        if px >= @constraint.w or py >= @constraint.h
          @constraint.set_wh(px+20, py+20)
        end
        @sx = @constraint.xc - (px/2)
        @sy = @constraint.yc - (py/2)
      end
    end
    # Draws the shape with a graphics object.
    # @param graphics [FXDCWindow] the display component on which
    #                              the shape will be drawn.
    # @param tick [Float] the length of the current game loop.
    def draw (graphics, tick)
      #based on the size of the font so 12pt = 16px per character?
      #points = pixels * 72 / dpi
      #dpi is specific to the computer...mine is 118
      #http://dpi.lv/
      #(points * dpi) / 72 = pixels per character
      if @font and @content
        graphics.foreground = @theme.font_color
        graphics.font = @font
        graphics.drawText(@sx,@sy,@content)
      end
      if @theme.fill_color
        graphics.foreground = @theme.fill_color
        graphics.fillRectangle(@constraint.x, @constraint.y,
          @constraint.w, @constraint.h)
      end
      if @theme.stroke_color
        graphics.foreground = @theme.stroke_color
        graphics.drawRectangle(@constraint.x, @constraint.y,
          @constraint.w, @constraint.h)
      end
    end
    
    def load(app)
      @font = @theme.font(app)
    end
    
    # Creates a deep copy of the object.
    # @return [LittleShape::Rectangle] a new rectangle object
    #                                  based on the current object.
    def clone
      Rectangle.new(@constraint.clone, @theme.clone)
    end
    
    # Short cut to reset x and y values according to the
    # given constraint.
    # @param constraint [Constraint] holds the new x and y values.
    def set (constraint)
      @constraint.set(constraint)
    end
    
    # Determines if a point intersects with this shape.
    # @param x [Fixnum] is the x coordinate.
    # @param y [Fixnum] is the y coordinate.
    # @return true if the point is inside, false otherwise.
    def contains?(x, y)
      @constraint.x <= x and @constraint.x1 >= x and @constraint.y <= y and @constraint.y1 >= y
    end
    
    # Creates a string representation of the object.
    # @return [String] a string that shows information about the theme
    #   and constraints.
    def to_s
      str = "Rectangle:\n"
      str += "\tConstraint: " + (@constraint ? @constraint.to_s : "*") + "\n"
      str += "\tTheme: " + (@theme ? @theme.to_s : "*")
      return str
    end
  end
end
