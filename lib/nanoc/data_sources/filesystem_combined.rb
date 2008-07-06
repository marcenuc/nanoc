module Nanoc::DataSources

  # = Pages
  #
  # The filesystem data source stores its pages in nested directories. A page
  # is represented by a single file. The root directory is the 'content'
  # directory.
  #
  # The metadata for a page is embedded into the file itself. It is stored at
  # the top of the file, between '-----' (five dashes) separators. For
  # example:
  #
  #   -----
  #   filters_pre: [ 'redcloth' ]
  #   -----
  #   h1. Hello!
  #
  # The path of a page is determined as follows. A file with an 'index.*'
  # filename, such as 'index.txt', will have the filesystem path with the
  # 'index.*' part stripped as a path. For example, 'foo/bar/index.html' will
  # have '/foo/bar/' as path.
  #
  # A file with a filename not starting with 'index.', such as 'foo.html',
  # will have a path ending in 'foo/'. For example, 'foo/bar.html' will have
  # '/foo/bar/' as path.
  #
  # Note that it is possible for two different, separate files to have the
  # same path. It is therefore recommended to avoid such situations.
  #
  # Some more examples:
  #
  #   content/index.html          --> /
  #   content/foo.html            --> /foo/
  #   content/foo/index.html      --> /foo/
  #   content/foo/bar.html        --> /foo/bar/
  #   content/foo/bar/index.html  --> /foo/bar/
  #
  # File extensions are ignored by nanoc. The file extension does not
  # determine the filters to run on it; the metadata in the file defines the
  # list of filters.
  #
  # = Page defaults
  #
  # The page defaults are loaded from a YAML-formatted file named 'meta.yaml'
  # file at the top level of the nanoc site directory.
  #
  # = Assets
  #
  # TODO write me
  #
  # = Asset defaults
  #
  # TODO write me
  #
  # = Layouts
  #
  # Layouts are stored as files in the 'layouts' directory. Similar to pages,
  # each layout consists of a metadata part and a content part, separated by
  # '-----'.
  #
  # = Templates
  #
  # Templates are located in the 'templates' directory. Templates are, just
  # like pages, files consisting of a metadata part and a content part,
  # separated by '-----'.
  #
  # = Code
  #
  # Code is stored in '.rb' files in the 'lib' directory. Code can reside in
  # sub-directories.
  class FilesystemCombined < Nanoc::DataSource

    ########## Attributes ##########

    identifier :filesystem_combined

    ########## Preparation ##########

    def up # :nodoc:
    end

    def down # :nodoc:
    end

    def setup # :nodoc:
      # Create pages
      FileUtils.mkdir_p('content')

      # Create template
      FileUtils.mkdir_p('templates')

      # Create layout
      FileUtils.mkdir_p('layouts')

      # Create code
      FileUtils.mkdir_p('lib')
    end

    def destroy # :nodoc:
      FileUtils.remove_entry_secure('meta.yaml')
      FileUtils.remove_entry_secure('content')
      FileUtils.remove_entry_secure('templates')
      FileUtils.remove_entry_secure('layouts')
      FileUtils.remove_entry_secure('lib')
    end

    ########## Pages ##########

    def pages # :nodoc:
      files('content', true).map do |filename|
        # Read and parse data
        meta, content = *parse_file(filename, 'page')

        # Skip drafts
        return nil if meta[:is_draft]

        # Get attributes
        attributes = meta.merge(:file => Nanoc::Extra::FileProxy.new(filename))

        # Get actual path
        if filename =~ /\/index\.[^\/]+$/
          path = filename.sub(/^content/, '').sub(/index\.[^\/]+$/, '') + '/'
        else
          path = filename.sub(/^content/, '').sub(/\.[^\/]+$/, '') + '/'
        end

        # Get mtime
        mtime = File.stat(filename).mtime

        # Build page
        Nanoc::Page.new(content, attributes, path, mtime)
      end.compact
    end

    def save_page(page) # :nodoc:
      # Find page path
      if page.path == '/'
        paths         = Dir['content/index.*']
        path          = paths[0] || 'content/index.html'
        parent_path   = '/'
      else
        last_path_component = page.path.split('/')[-1]
        paths_best    = Dir['content' + page.path[0..-2] + '.*']
        paths_worst   = Dir['content' + page.path + 'index.*']
        path_default  = 'content' + page.path[0..-2] + '.html'
        path          = paths_best[0] || paths_worst[0] || path_default
        parent_path   = '/' + File.join(page.path.split('/')[0..-2])
      end

      # Notify
      if File.file?(path)
        Nanoc::NotificationCenter.post(:file_updated, path)
      else
        Nanoc::NotificationCenter.post(:file_created, path)
      end

      # Write page
      FileUtils.mkdir_p('content' + parent_path)
      File.open(path, 'w') do |io|
        io.write("-----\n")
        io.write(page.attributes.to_split_yaml + "\n")
        io.write("-----\n")
        io.write(page.content)
      end
    end

    def move_page(page, new_path) # :nodoc:
      # TODO implement
    end

    def delete_page(page) # :nodoc:
      # TODO implement
    end

    ########## Assets ##########

    # def assets # :nodoc:
    #   # TODO implement (high)
    # end
    # 
    # def save_asset(asset) # :nodoc:
    #   # TODO implement (high)
    # end
    # 
    # def move_asset(asset, new_path) # :nodoc:
    #   # TODO implement
    # end
    # 
    # def delete_asset(asset) # :nodoc:
    #   # TODO implement
    # end

    ########## Page Defaults ##########

     def page_defaults # :nodoc:
      # Get attributes
      attributes = YAML.load_file('meta.yaml') || {}

      # Get mtime
      mtime = File.stat('meta.yaml').mtime

      # Build page defaults
      Nanoc::PageDefaults.new(attributes, mtime)
    end

    def save_page_defaults(page_defaults) # :nodoc:
      # Notify
      if File.file?('meta.yaml')
        Nanoc::NotificationCenter.post(:file_updated, 'meta.yaml')
      else
        Nanoc::NotificationCenter.post(:file_created, 'meta.yaml')
      end

      # Write page defaults
      File.open('meta.yaml', 'w') do |io|
        io.write(page_defaults.attributes.to_split_yaml)
      end
    end

    ########## Asset defaults ##########

    # def asset_defaults # :nodoc:
    #   # TODO implement (high)
    # end
    # 
    # def save_asset_defaults(asset_defaults) # :nodoc:
    #   # TODO implement (high)
    # end

    ########## Layouts ##########

    def layouts # :nodoc:
      files('layouts', true).map do |filename|
        # Read and parse data
        meta, content = *parse_file(filename, 'layout')

        # Get actual path
        if filename =~ /\/index\.[^\/]+$/
          path = filename.sub(/^layouts/, '').sub(/index\.[^\/]+$/, '') + '/'
        else
          path = filename.sub(/^layouts/, '').sub(/\.[^\/]+$/, '') + '/'
        end

        # Get mtime
        mtime = File.stat(filename).mtime

        # Build layout
        Nanoc::Layout.new(content, meta, path, mtime)
      end.compact
    end

    def save_layout(layout) # :nodoc:
      # Find layout path
      last_path_component = layout.path.split('/')[-1]
      paths_best    = Dir['layouts' + layout.path[0..-2] + '.*']
      paths_worst   = Dir['layouts' + layout.path + 'index.*']
      path_default  = 'layouts' + layout.path[0..-2] + '.html'
      path          = paths_best[0] || paths_worst[0] || path_default
      parent_path   = '/' + File.join(layout.path.split('/')[0..-2])

      # Notify
      if File.file?(path)
        Nanoc::NotificationCenter.post(:file_updated, path)
      else
        Nanoc::NotificationCenter.post(:file_created, path)
      end

      # Write layout
      FileUtils.mkdir_p('layouts' + parent_path)
      File.open(path, 'w') do |io|
        io.write("-----\n")
        io.write(layout.attributes.to_split_yaml + "\n")
        io.write("-----\n")
        io.write(layout.content)
      end
    end

    def move_layout(layout, new_path) # :nodoc:
      # TODO implement
    end

    def delete_layout(layout) # :nodoc:
      # TODO implement
    end

    ########## Templates ##########

    def templates # :nodoc:
      files('templates', false).map do |filename|
        # Read and parse data
        meta, content = *parse_file(filename, 'template')

        # Get name
        name = filename.sub(/^templates\//, '').sub(/\.[^\/]+$/, '')

        # Build template
        Nanoc::Template.new(content, meta, name)
      end.compact
    end

    def save_template(template) # :nodoc:
      # Get template path
      paths         = Dir[File.join('templates', template.name) + '.*']
      path_default  = File.join('templates', template.name) + '.html'
      path          = paths[0] || path_default

      # Notify
      if File.file?(path)
        Nanoc::NotificationCenter.post(:file_updated, path)
      else
        Nanoc::NotificationCenter.post(:file_created, path)
      end

      # Write template
      File.open(path, 'w') do |io|
        io.write("-----\n")
        io.write(template.page_attributes.to_split_yaml + "\n")
        io.write("-----\n")
        io.write(template.page_content)
      end
    end

    def move_template(template, new_name) # :nodoc:
      # TODO implement
    end

    def delete_template(template) # :nodoc:
      # TODO implement
    end

    ########## Code ##########

    def code # :nodoc:
      # Get data
      data = Dir['lib/**/*.rb'].sort.map { |filename| File.read(filename) + "\n" }.join('')

      # Get modification time
      mtime = Dir['lib/**/*.rb'].map { |filename| File.stat(filename).mtime }.inject { |memo, mtime| memo > mtime ? mtime : memo}

      # Build code
      Nanoc::Code.new(data, mtime)
    end

    def save_code(code) # :nodoc:
      # Check whether code existed
      existed = File.file?('lib/default.rb')

      # Remove all existing code files
      Dir['lib/**/*.rb'].each { |f| FileUtils.remove_entry_secure(f) }

      # Notify
      if existed
        Nanoc::NotificationCenter.post(:file_updated, 'lib/default.rb')
      else
        Nanoc::NotificationCenter.post(:file_created, 'lib/default.rb')
      end

      # Write code
      File.open('lib/default.rb', 'w') do |io|
        io.write(code.data)
      end
    end

  private

    # Returns a list of all files in +dir+, ignoring any backup files (files
    # that end with a ~).
    #
    # +recursively+:: When +true+, finds files in +dir+ as well as its
    #                 subdirectories; when +false+, only searches +dir+
    #                 itself.
    def files(dir, recursively)
      glob = File.join([dir] + (recursively ? [ '**', '*' ] : [ '*' ]))
      Dir[glob].reject { |f| File.directory?(f) or f =~ /~$/ }
    end

    # Parses the file named +filename+ and returns an array with its first
    # element a hash with the file's metadata, and with its second element the
    # file content itself.
    def parse_file(filename, kind)
      # Split file
      pieces = File.read(filename).split(/^-----/)
      if pieces.size < 3
        raise RuntimeError.new(
          "The file '#{filename}' does not seem to be a nanoc #{kind}"
        )
      end

      # Parse
      meta    = YAML.load(pieces[1])
      content = pieces[2..-1].join.strip

      [ meta, content ]
    end

  end

end