#!/usr/bin/env ruby

#Resources used:
#http://www.fxruby.org/doc/book.html
#http://www.rubydoc.info/gems/fxruby/


=begin
This is a basic game engine meant for expirementation
and learning. It's overly commented without too many
bells and whistles. It probably has some bad habits
and is not the most efficient design.

If you want a serious game engine, this is not it.
If you want a framework that's easy to play with
then you're in the right place.

All resources used are easy to find and install. As
a note, this was created using Ruby 2.2.4.23 on
Windows 7. Please see the README for directions
on how to run this demo.

THIS IS THE DEBUG VERSION. It has an optional debug window to display
error messages in.

@author  Melinda Robertson
@version 1.3
=end

#for logging events in a file
require_relative 'littlelog'
#handles input events
require_relative 'littleinput'

#I'm using fxruby for the GUI portion.
require 'fox16'
include Fox

#How many milliseconds the loop should take to run.
$MS_PER_FRAME = 0.01
#Set this to true to display the debug window.
$DEBUG = true
#Set this to true to save statistics and comments to file.
$LOG = true

#Game objects do all the heavy lifting in the game.
#If there's something to see there's a game object
#behind it. If there's something to do, there's a
#game object doing it.
#To use the game object, overwrite the functions.
class GameObject
    attr_accessor :group
    attr_accessor :remove
    # Creates the object.
    # @param group [Group] is the group this object belongs to.
    def initialize (game, group)
      @game = game
      @group = group
      @remove = false
    end
    # Update variables (hint: position) here.
    def update(params={})
    end
    # Draw the object (picture or shape) using
    # the graphics from the canvas.
    # @param graphics [FXDCWindow] is the graphics object with
    #                              which to draw.
    # @param tick [Numerical] is the milliseconds since the last
    #                         game loop started.
    def draw (graphics, tick)
    end
    def load (app)
    end
end
# I use groups to separate game objects into
# categories. This helps with layering when objects
# have overlapping positions on the screen.
class Group
    attr_accessor :scene
    # Creates the group.
    # @param scene [Scene] is the scene this group belongs to.
    def initialize (game, scene)
      @game = game
      @entities = []
      @scene = scene
    end
    # Updates the objects in this group.
    def update(params={})
        @entities.each {|i| i.update(params)}
        @entities.delete_if {|i| i.remove}
    end
    # Tells the objects in this group to draw.
    # @param graphics [FXDCWindow] is the graphics object with
    #                              which to draw.
    # @param tick [Numerical] is the milliseconds since the last
    #                         game loop started.
    def draw (graphics, tick)
        @entities.each {|i| i.draw(graphics, tick)}
    end
    def load (app)
      @entities.each {|i| i.load(app)}
    end
    # Add a new object to this group.
    # @param value [GameObject] is the object to add.
    def push (value)
        @entities.push(value)
    end
    # Retrieve one of the objects in the group.
    # @param value [Fixnum] is the index of the object.
    def [] (value)
      return @entities[value]
    end
    def slice!(value)
      @entities.slice!(value)
    end
    def contains(value)
      @entities.contains(value)
    end
    def index(value)
      @entities.index(value)
    end
    def size
      @entities.size
    end
end
# The scene is a convenient way to switch entire sets
# of objects. This way, the game can switch levels or
# from a title screen to a level and back.
# The scene is generally the object that should be
# overwritten to create custom levels.
class Scene
    # Initializes the scene by setting up variables
    # and adding starting groups.
    # @param game [LittleGame] is the game object owner.
    def initialize (game,param={})
      @game = game
      @groups = Hash.new
    end
    # Calls update on all the groups.
    def update (params={})
      @groups.each{|key, value| value.update(params)}
    end
    # Calls draw on all the groups.
    # If a particular layering scheme needs to be
    # used, overwrite this.
    # @param graphics [FXDCWindow] is the graphics object with
    #                              which to draw.
    # @param tick [Float] is the milliseconds since the last
    #                         game loop started.
    def draw (graphics, tick)
      @groups.each{|key, value| value.draw(graphics, tick)}
    end
    def load (app)
      @groups.each {|key, value| value.load(app)}
    end
    # Adds a new game object to the indicated group.
    # If the group doesn't exist, it adds a new group.
    # @param group [Group] is the group to add the object to.
    # @param value [GameObject] is the object to add.
    def push (group, value)
        if (!@groups[group])
            @groups[group] = Group.new(@game, self)
        end
        value.group = @groups[group]
        @groups[group].push(value)
    end
    # Removes the indicated game object from the scene.
    # @param group [Group] is the group the object belongs to.
    # @param value [Fixnum] is the index of the object to remove.
    def remove_index (group, value)
      @groups[:group].slice!(value)
    end
    # Removes a game object from the scene.
    # @param value [GameObject] is the object to remove.
    # @return true if the object was removed,
    #         false otherwise.
    def remove_obj(value)
      @groups.each do |i|
        if i.contains(value)
          i.slice!(i.index(value))
          return true
        end
      end
      return false
    end
    def [](sym)
      @groups[sym]
    end
    # The input map that relates input events to method names.
    # @return [Hash] of type [Numerical, Symbol] where events are
    #                registered as numbers (the input code) and
    #                responses are symbols representing method names.
    def input_map
      {}
    end
end
# Here are guts of the game engine. This has the
# actual game loop which runs continuosly, updating
# each object until the program is halted.
# I recommend checking out
# http://gameprogrammingpatterns.com/game-loop.html
# to see how a game loop works. This website was
# used as the resource for this engine.
class LittleGame
    # @!attribute [r] canvas
    #   @return [FXCanvas] is the canvas object to draw on.
    attr_reader   :canvas
    # @!attribute [r] tick
    #   @return [Numerical] is the time since the last game loop.
    attr_reader   :tick
    # @!attribute [rw] scene
    #   @return [Scene] is the current scene.
    attr_accessor   :scene
    # @!attribute [rw] input
    #   @return [LittleInput::Input] manages user input.
    attr_accessor   :input
    # @!attribute [rw] end_game
    # @return [Boolean] determines whether or not to continue.
    attr_accessor   :end_game
    
    # Creates the game and the variables needed
    # to time the loop correctly.
    def initialize (newscene=nil, param={})
        @tick = 0
        @time = Time.now
        @input = LittleInput::Input.new(self)
        @scene = nil
        @canvas = nil
        if newscene
          @newscene = newscene.new(self,param)
        end
    end
    # Creates listeners for the canvas when it is added.
    # @param canvas [FXCanvas] is the canvas object for which input
    #                          is required.
    def canvas=(canvas)
      @canvas = canvas
      if @canvas and @input
        @canvas.connect(SEL_KEYPRESS) do |sender, selector, data|
          @input.add(data.code, {code: data.code,
            state: LittleInput::PRESS, time: data.time})
        end
        @canvas.connect(SEL_KEYRELEASE) do |sender, selector, data|
          @input.add(data.code, {code: data.code,
            state: LittleInput::RELEASE, time: data.time})
        end
        @canvas.connect(SEL_LEFTBUTTONPRESS) do |sender, selector, data|
          @input.add(LittleInput::MOUSE_LEFT,
            {x: data.click_x, y: data.click_y, time: data.time})
        end
        @canvas.connect(SEL_RIGHTBUTTONPRESS) do |sender, selector, data|
          @input.add(LittleInput::MOUSE_RIGHT,
            {x: data.click_x, y: data.click_y, time: data.time})
        end
        @canvas.connect(SEL_MIDDLEBUTTONPRESS) do |sender, selector, data|
          @input.add(LittleInput::MOUSE_MIDDLE,
            {x: data.click_x, y: data.click_y, time: data.time})
        end
        @canvas.connect(SEL_MOUSEWHEEL) do |sender, selector, data|
          @input.add(LittleInput::MOUSE_WHEEL,
            {x: data.click_x, y: data.click_y,
            type: data.type, state: data.state,
            click_count: data.click_count, time: data.time})
        end
        @canvas.connect(SEL_MOTION) do |sender, selector, data|
          @input.add(LittleInput::MOUSE_MOTION,
            {x1: data.last_x, y1: data.last_y,
            x2: data.click_x, y2: data.click_y, time: data.time})
        end
      end
      start_input if @canvas and @scene and @input
    end
    # Sets the new scene to be updated on the
    # next run of the loop.
    # @param scene [Scene] is the new scene.
    def changescene (scene)
        @newscene = scene
    end
    # Connects the current scene to the input manager.
    def start_input
      if @scene
        @input.connect(@scene, @scene.input_map)
      end
    end
    # This method is called to begin the loop.
    # Notice that this has no looping structure.
    # The 'loop' portion is actually in the GUI.
    def run
        #$FRAME.log(1, "Running.")
        return if not @canvas
        if @end_game
          $FRAME.on_close(self,nil,:end_game)
        end
        #if the scene has been changed, switch out the old scene
        #and switch input to the new scene.
        if (@newscene)
            @scene = @newscene
            @newscene = nil
            start_input if @canvas and @input
            @scene.load($FRAME.getApp())
        end
        lasttick = (@time.to_f)
        @time = Time.now
        @tick = (@time.to_f)-lasttick
        loop
    end
    # The guts and glory of the game loop.
    # This guy does all the heavy lifting.
    def loop
        input
        while (@tick > $MS_PER_FRAME) do
            update
            @tick -= $MS_PER_FRAME
        end
        graphics = FXDCWindow.new(@canvas)
        draw(graphics, @tick)
        graphics.end
    end
    # Process the input.
    def input
      while @input.execute
        #as long as there is input to process
        #keep calling execute on the input manager
      end
    end
    # Update the objects.
    def update
        @scene ? @scene.update : nil
    end
    # Draw the objects.
    # @param graphics [FXDCWindow] is the graphics object with
    #                              which to draw.
    # @param tick [Numerical] is the milliseconds since the last
    #                         game loop started.
    def draw (graphics, tick)
        graphics.foreground = @canvas.backColor
        graphics.fillRectangle(0, 0, @canvas.width, @canvas.height)
        @scene ? @scene.draw(graphics, tick) : nil
    end
    def to_s
      text = "time:#{@time}, tick:#{@tick}, EG:#{@end_game}\n"
      text += @scene.to_s
      return text
    end
end
# This is the program window that holds the canvas.
# The canvas is where everything is drawn. The frame
# also calls the run method periodically to keep the
# game going. The framework used is from fxruby.
class LittleFrame < FXMainWindow
    # @!attribute [r] logger
    #   @return [LittleLogger] 
    attr_reader :logger
    # Creates the window components and adds the game.
    # @param app [FXApp] is the application that will be running.
    # @param w [Fixnum] is the width in pixels.
    # @param h [Fixnum] is the height in pixels.
    # @param game [LittleGame] is the game engine.
    def initialize (w, h)
        app = FXApp.new('Little Game', 'Test')
        myh = h
        if $DEBUG #make room for the log console
          myh = (h*1.4)
        end
        super(app, "Game Frame", :width => w, :height => myh)
        @app = app #this is the main application
        #@contents = FXVerticalFrame.new(self, LAYOUT_FILL_X|LAYOUT_FILL_Y)
        @contents = FXVerticalFrame.new(self, LAYOUT_FILL_X)
        @canvas = FXCanvas.new(@contents, :opts => LAYOUT_FILL_X|LAYOUT_FILL_Y|LAYOUT_TOP|LAYOUT_LEFT)
        if $DEBUG #create the console for debug messages
          debugframe = FXVerticalFrame.new(@contents,:opts => FRAME_SUNKEN|LAYOUT_FILL_X|LAYOUT_TOP|LAYOUT_LEFT)
          FXLabel.new(debugframe, "Console", nil, JUSTIFY_CENTER_X|LAYOUT_FILL_X)
          FXHorizontalSeparator.new(debugframe, SEPARATOR_RIDGE|LAYOUT_FILL_X)
          @@console = FXText.new(debugframe, opts: TEXT_READONLY|TEXT_WORDWRAP|TEXT_AUTOSCROLL|LAYOUT_FILL_X)
          @@console.setText("Starting...\n")
        end
        @@logger = LittleLogger.new if $LOG
        @canvas.backColor = Fox.FXRGB(0, 0, 0)
        self.connect(SEL_CLOSE, method(:on_close))
    end
    # Creates the application, adds a timeout function
    # that calls the run method periodically, shows
    # the window and starts the game.
    def start (game)
      game.canvas = @canvas
      @game = game
      @app.create
      @app.addTimeout($MS_PER_FRAME * 1000.0, :repeat => true) do
        if $LOG
          @@logger.inc(:run)
        end
        begin
          @game.run
        rescue
          @game.end_game = true
          $FRAME.log(1, "Frame:run:An error occured; " + @game.to_s, true)
        end
        #Messages can be logged by using this command
        #anywhere in the running game.
        #$FRAME.log(0, "Game is running")
      end
      show(PLACEMENT_SCREEN)
      @app.run
    end
    # Shows details of the frame and its objects.
    # @return [String] representation of the application.
    def to_s
        str = ""
        str += @app.to_s
        str += "\n" + @game.to_s
        str += "\n" + @canvas.to_s
    end
    # Logs a comment to the console.
    # @param id [Numerical] is the error id if applicable.
    # @param message [String] is the message to pint to the console.
    # @param exit [true, false] is the optional parameter to signal
    #                          the application to close.
    def log (id=0, message="test", exit=false)
      if @@console
        time = Time.now
        @@console.appendText("#{time}: #{id}: #{message}\n")
      end
      if $LOG
        logtofile(self,"log",message)
      end
      if exit
        on_close(self,nil,:error)
      end
    end
    # Adds a line to the log file.
    # @param sender [Object] is the object that made the request.
    # @param method [String] is the method name this was called from.
    # @param note [String] is the note to save to the log file.
    def logtofile(sender, method="", note="")
      @@logger.logtofile(sender, method, note) if @@logger
    end
    # Overwrite exiting so that the log file can be saved
    # and any cleanup operations can be performed.
    def on_close(sender, selector, event)
      if $LOG
        @@logger.save
      end
      getApp().exit(0)
    end
end

