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
  end
end

class Label < GameObject
  def initialize (game, group, x, y, w, h, content)
    super (game, group)
    @shape = LittleShape::Rectangle.new(Constraint.new(x, y, w, h), Theme.new)
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
  def initialize (game, group, x,y,w,h)
    super(game, group, x,y,w,h,RedBlueTheme.new)
  end
  
  def contains?(x, y)
    @shape.contains?(x, y)
  end
end

class Line < GameObject
  def initialize (game, group, x_start, y_start, x_end, y_end)
    super(game, group)
    @theme = RedBlueTheme.new
    @x = x_start
    @y = y_start
    @x1 = x_end
    @y1 = y_end
  end

  def draw(graphics, tick)
    graphics.foreground = @theme.fill_color
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

  def initialize (game, group, x_start, y_start, x_end, y_end, scale, limit, orientation)
    super (game, group, x_start, y_start, x_end, y_end)
    @scale = scale
    @limit = limit
    @orientation = orientation
  end
  def draw(graphics, tick)
    #TODO
  end
end

class Graph < Group
  # Defines a graph that covers the space of the canvas
  # and has specific parts to it that act in tandem.
  # @param x_scale [Fixnum] determines the space between ticks for the x axis.
  # @param y_scale [Fixnum] determines the space between ticks for the y axis.
  # @param x_limit [Fixnum] the upper-bound on the x axis.
  # @param y_limit [Fixnum] the upper-bound on the y axis.
  def initialize(game, scene, x_scale, y_scale, x_limit, y_limit)
    super(game, scene)
    #create x and y axis using the scales and limits
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