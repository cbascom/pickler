class Pickler
  class Runner

    attr_reader :argv

    def pickler
      @pickler ||= Pickler.new(Dir.getwd)
    end

    def initialize(argv)
      @argv = argv
      @tty = $stdout.tty?
    end

    COLORS = {
      :black   => 0,
      :red     => 1,
      :green   => 2,
      :yellow  => 3,
      :blue    => 4,
      :magenta => 5,
      :cyan    => 6,
      :white   => 7
    }

    STATE_COLORS = {
      nil           => COLORS[:black],
      "rejected"    => COLORS[:red],
      "accepted"    => COLORS[:green],
      "delivered"   => COLORS[:yellow],
      "unscheduled" => COLORS[:white],
      "started"     => COLORS[:magenta],
      "finished"    => COLORS[:cyan],
      "unstarted"   => COLORS[:blue]
    }

    STATE_SYMBOLS = {
      "unscheduled" => "  ",
      "unstarted"   => ":|",
      "started"     => ":/",
      "finished"    => ":)",
      "delivered"   => ";)",
      "rejected"    => ":(",
      "accepted"    => ":D"
    }

    TYPE_COLORS = {
      'chore'   => COLORS[:blue],
      'feature' => COLORS[:magenta],
      'bug'     => COLORS[:red],
      'release' => COLORS[:cyan]
    }

    TYPE_SYMBOLS = {
      "feature" => "*",
      "chore"   => "%",
      "release" => "!",
      "bug"     => "/"
    }

    def color?
      case pickler.config["color"]
      when "always" then true
      when "never"  then false
      else
        @tty && RUBY_PLATFORM !~ /mswin|mingw/
      end
    end

    def puts_summary(story)
      summary = "%6d " % story.id
      type  = story.estimate || TYPE_SYMBOLS[story.story_type]
      state = STATE_SYMBOLS[story.current_state]
      if color?
        summary << "\e[3#{STATE_COLORS[story.current_state]}m#{state}\e[00m "
        summary << "\e[01;3#{TYPE_COLORS[story.story_type]}m#{type}\e[00m "
      else
        summary << "#{state} #{type} "
      end
      summary << story.name
      puts summary
    end

    def paginated_output
      stdout = $stdout
      if @tty && pager = pickler.config["pager"]
        # Modeled after git
        ENV["LESS"] ||= "FRSX"
        IO.popen(pager,"w") do |io|
          $stdout = io
          yield
        end
      else
        yield
      end
    ensure
      $stdout = stdout
    end

    def run
      case first = argv.shift
      when 'show', /^\d+$/
        story = pickler.project.story(first == 'show' ? argv.shift : first)
        paginated_output do
          puts story
        end
      when 'search'
        stories = pickler.project.stories(*argv)
        stories.reject! {|s| %w(unscheduled unstarted accepted).include?(s.current_state)} if argv.empty?
        paginated_output do
          stories.each do |story|
            puts_summary story
          end
        end
      when 'push'
        pickler.push(*argv)
      when 'pull'
        pickler.pull(*argv)
      when 'start'
        pickler.start(argv.first,argv[1])
      when 'finish'
        pickler.finish(argv.first)
      when 'help', '--help', '-h', '', nil
        puts 'pickler commands: [show|start|finish] <id>, search <query>, push, pull'
      else
        $stderr.puts "pickler: unknown command #{first}"
        exit 1
      end
    rescue Pickler::Error
      $stderr.puts "#$!"
      exit 1
    rescue Interrupt
      $stderr.puts "Interrupted!"
      exit 130
    end

  end
end