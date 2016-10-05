#!/usr/bin/env ruby

=begin
Somehow I want to create a scene that draws a graph.

The scene should have:

line drawing
a button
labels


=end

require_relative 'littleshape'
require_relative 'littleengine'

class RedBlueTheme < Theme
  def initialize
    @stroke_color = Fox.FXRGB(179, 0, 0) #red
    @fill_color = Fox.FXRGB(102, 153, 204) #blue
    @font_color = Fox.FXRGB(179, 0, 0) #red
    @highlight_color = Fox.FXRGB(224, 224, 235) #light greyish blue
  end
end

class Label < GameObject
  def initialize (game, group, x, y, w, h, content, theme=Theme.new)
    super (game, group)
    @shape = LittleShape::Rectangle.new(Constraint.new(x, y, w, h), theme)
    @font_color = Fox.FXRGB(179, 0, 0)
    @content = content
  end
  
  def draw (graphics, tick)
    #draws the shape and the string content
    @shape.draw(graphics, tick, @content)
  end
  
  def load(app)
    @shape.load(app)
  end
end

class Button < Label
  def initialize (game, group, x,y,w,h, content)
    super(game, group, x,y,w,h,content, RedBlueTheme.new)
  end
  
  def contains?(x, y)
    @shape.contains?(x, y)
  end
end

class Line < GameObject
  def initialize (game, group, theme, x_start, y_start, x_end, y_end)
    super(game, group)
    @theme = theme
    @x = x_start
    @y = y_start
    @x1 = x_end
    @y1 = y_end
  end

  def draw(graphics, tick)
    graphics.foreground = @theme.highlight_color
    graphics.drawLine(@x,@y,@x1,@y1)
  end
  
  def move(x, y, x1, y1)
    @x = x
    @y = y
    @x1 = x1
    @x2 = x2
  end
end

class Axis < Line
  #Orient starts from origin (0,0)
  def initialize (game, group, theme, x_start, y_start, x_end, y_end, scale, limit)
    super (game, group, theme, x_start, y_start, x_end, y_end)
    @scale = scale
    @limit = limit
    @ticks = []
    if x_start == x_end #vertical
      #ok so it starts at 0 and goes to limit
      # scale is how much space b/t the tick marks
      t = 0
      #----|----|
      px_total = (y_start - y_end) #how many pixels we have to work with
      #how many time does the scale fit into the limit?
      howmanyticks = limit / scale
      #now how many pixels are for each tick
      px_tick = px_total / howmanyticks
      c = 0
      while (t+scale) < limit
        y = y_start+(px_tick*c)
        @ticks.push(TickMark.new(game,group,theme,x_start-5,y,x_end+5,y,t.to_s))
        t += scale
        c += 1
      end
      @ticks.push(TickMark.new(game,group,theme,x_start-5,y_end,x_end+5,y_end,limit.to_s)
    else if y_start == y_end #horizontal
      t = 0
      px_total = (x_start - x_end)
      howmanyticks = limit / scale
      px_tick = px_total / howmanyticks
      c = 0
      while (t+scale) < limit
        x = x_start+(px_tick*c)
        @ticks.push(TickMark.new(game,group,theme,x,y_start-5,x,y_end+5,t.to_s))
        t += scale
        c += 1
      end
      @ticks.push(TickMark.new(game,group,theme,x_end,y_start-5,x_end,y_start+5, limit.to_s))
    end
  end
  def draw(graphics, tick)
    #TODO need to draw the line plus the tick marks
    # tick marks are a standard width, say 5 px and have a label attached
    # halfway on the string needs to be the tick mark
  end
  
  class TickMark < Line
    def initialize (game, group, theme, x_start, y_start, x_end, y_end, content)
      super(game, group, theme, x_start, y_start, x_end, y_end)
      @content = content
    end
    def draw (graphics, tick)
      super
      sx = @x
      sy = @y
      if @x == @x1 #vertical
        sx = @x - 5
        sy = @y - ((@theme.font_size * $DPI) / 36)
      else if @y == @y1 #horizontal
        sx = @x - (((@theme.font_size * $DPI) / 72) * @content.size * $FONT_WIDTH_RATIO)/2
        sy = @y1 + 5
      end
      graphics.foreground = @theme.font_color
      graphics.font = @theme.font
      graphics.drawText(sx,sy,content)
    end
  end
end

class Graph < Group
  # Defines a graph that covers the space of the canvas
  # and has specific parts to it that act in tandem.
  # @param x_scale [Fixnum] determines the space between ticks for the x axis.
  # @param y_scale [Fixnum] determines the space between ticks for the y axis.
  # @param x_limit [Fixnum] the upper-bound on the x axis.
  # @param y_limit [Fixnum] the upper-bound on the y axis.
  def initialize(game, scene, x,y,w,h,x_scale, y_scale, x_limit, y_limit)
    super(game, scene)
    @x_axis = Axis.new(game,:graph,)
    #create x and y axis using the scales and limits
    @theme = RedBlueTheme.new
  end
  def load (app)
    super
    @theme.font(app)
  end
  def scale (x,y)
    #need to get the pixel point of an x,y value on the plot
  end
end

class ButtonScene < Scene
  def initialize (game)
    super
    push(:menu, Button.new(game,:menu))
  end
  
  def input_map
    {LittleInput::MOUSE_LEFT => :click}
  end
  
  def click (args)
    btn = grous[:menu][0]
    if btn.contains?(args[:x], args[:y])
      #TODO switch the scene
    end
  end
end