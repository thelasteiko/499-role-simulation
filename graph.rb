#!/usr/bin/env ruby

=begin
Somehow I want to create a scene that draws a graph.

Graph < Group
  RedBlueTheme < Theme <----distributed to all subordinate objects
  Button < Label < GameObject
  Axis < Line < GameObject
    Label < GameObject
      Theme
      Constraint

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
    theme.font_color = Fox.FXRGB(179, 0, 0)
    @shape = LittleShape::Rectangle.new(Constraint.new(x, y, w, h), theme, content)
  end
  
  def draw (graphics, tick)
    #draws the shape and the string content
    @shape.draw(graphics, tick)
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
#-----------------------------------------------------------------------
class Line < GameObject
  attr_reader :x
  attr_reader :y
  attr_reader :x1
  attr_reader :y1
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

class Graph < Group
  # Defines a graph that covers the space of the canvas
  # and has specific parts to it that act in tandem.
  # @param x_scale [Fixnum] determines the space between ticks for the x axis.
  # @param y_scale [Fixnum] determines the space between ticks for the y axis.
  # @param x_limit [Fixnum] the upper-bound on the x axis.
  # @param y_limit [Fixnum] the upper-bound on the y axis.
  def initialize(game, scene, x,y,w,h,x_scale, y_scale, x_limit, y_limit)
    super(game, scene)
    @shape = LittleShape::Rectangle.new(Constraint.new(x,y,w,h), RedBlueTheme.new)
    @padding = 20
    #bounds: x+@padding, y+h-@padding, x+w-@padding, y+@padding
    #create x and y axis using the scales and limits
    @y_axis = Axis.new(game,@shape.theme,x+@padding,y+h-@padding,x+@padding,y+@padding,y_scale,y_limit)
    @x_axis = Axis.new(game,@shape.theme,x+@padding,y+h-@padding,x+w-@padding,y+h-@padding,x_scale,x_limit)
  end
  def load (app)
    super
    @shape.load(app)
  end
  def plot (x,y,code)
    #need to get the pixel point of an x,y value on the plot
    # x and y are at scale, if 0
    mx = @x_axis.x + @x_axis.px_tick * x
    my = @y_axis.y + @y_axis.px_tick * y
    if code == 1
      color = @shape.theme.stroke_color
    else if code == 2
      color = @shape.theme.fill_color
    else
      color = @shape.theme.highlight_color
    end
    push(Plot.new(@game,@shape.theme,mx,my,{x: x, y: y, color: color})
  end
class Axis < Line
  attr_reader :px_tick
  # Starting coordinate are from origin (0,0) on the graph.
  # @param game [LittleGame] is the main game object that runs everything.
  # @param group [Group] is the group this object belongs to in the scene.
  # @param theme [Theme] is the color scheme.
  # @param x_start [Fixnum] is the x coordinate for where the axis starts;
  #                         represents 0 on the graph.
  # @param y_start [Fixnum] is the y coordinate for where the axis starts;
  #                         represents 0 on the graph.
  # @param x_end [Fixnum] is the y coordinate for where the axis ends;
  #                         represents the limit on the graph.
  # @param y_end [Fixnum] is the y coordinate for where the axis ends;
  #                         represents the limit on the graph.
  # @param scale [Fixnum] is the distance between tick marks.
  # @param limit [Fixnum] determines the upper-bound on what the axis can represent.
  def initialize (game, theme, x_start, y_start, x_end, y_end, scale, limit)
    super (game, :graph, theme, x_start, y_start, x_end, y_end)
    @scale = scale
    @limit = limit
    @ticks = []
    #create tick marks
    if x_start == x_end #vertical
      t = 0 #number on the tick mark
      px_total = (y_start - y_end) #how many pixels we have to work with
      howmanyticks = limit / scale
      @px_tick = px_total / howmanyticks #pixels per tick
      c = 0 #how many ticks have we
      while (t+scale) < limit
        y = y_start+(px_tick*c)
        @ticks.push(TickMark.new(game,theme,x_start-5,y,x_end+5,y,t.to_s))
        t += scale
        c += 1
      end
      @ticks.push(TickMark.new(game,theme,x_start-5,y_end,x_end+5,y_end,limit.to_s)
    else if y_start == y_end #horizontal
      t = 0
      px_total = (x_start - x_end)
      howmanyticks = limit / scale
      @px_tick = px_total / howmanyticks
      c = 0
      while (t+scale) < limit
        x = x_start+(px_tick*c)
        @ticks.push(TickMark.new(game,theme,x,y_start-5,x,y_end+5,t.to_s))
        t += scale
        c += 1
      end
      @ticks.push(TickMark.new(game,theme,x_end,y_start-5,x_end,y_start+5, limit.to_s))
    end
  end
  
  def draw(graphics, tick)
    super
    @ticks.each {|i| i.draw(graphics,tick)}
  end
end
  #internal class for tick marks
  class TickMark < Line
    def initialize (game, theme, x_start, y_start, x_end, y_end, content)
      super(game, :graph, theme, x_start, y_start, x_end, y_end)
      @content = content
      @sx = @x
      @sy = @y
      if @x == @x1 #vertical
        @sx = @x - 5
        @sy = @y - ((@theme.font_size * $DPI) / 36)
      else if @y == @y1 #horizontal
        @sx = @x - (((@theme.font_size * $DPI) / 72) * @content.size * $FONT_WIDTH_RATIO)/2
        @sy = @y1 + 5
      end
    end
    def draw (graphics, tick)
      super
      graphics.foreground = @theme.font_color
      graphics.font = @theme.font #assuming its already been created
      graphics.drawText(@sx,@sy,@content)
    end
  end
  
  class Plot < GameObject
    def initialize(game, theme, x, y, data)
      super(game, :graph)
      @x = x
      @y = y
      @theme = theme
    end
    def draw(graphics, tick)
      
    end
  end
end

#Base scene to have a button that switches to another scene.
class SwitchScene < Scene
  # Creates the scene with a button.
  # @param  game [LittleGame] is the engine.
  def initialize (game)
    super (game)
    #game, group, x,y,w,h, content
    @btn_content = 'default'
    @new_scene = 'SwitchScene'
  end
  
  def input_map
    {LittleInput::MOUSE_LEFT => :click}
  end
  
  def load(app)
    super
    x = @game.canvas.width - 10
    y = @game.canvas.height - 10
    h = (12 * $DPI) / 72
    w = (h * @content.size * $FONT_WIDTH_RATIO) + 20
    h += 20
    push(:menu, Button.new(game,:menu, x,y,w,h, @btn_content))
  end
  
  def click (args)
    btn = grous[:menu][0]
    if btn.contains?(args[:x], args[:y])
      @game.changescene(Object.const_get(@new_scene).new(@game))
    end
  end
end