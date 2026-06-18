# encoding: UTF-8
# autocajon.rb — Loader AutoCajon para SketchUp 2017

require 'sketchup.rb'
require 'extensions.rb'

module BiraEstudio
  module AutoCajon
    unless defined?(@extension)
      loader = File.join(File.dirname(__FILE__), 'autocajon', 'main')
      @extension = SketchupExtension.new('AutoCajon', loader)
      @extension.creator     = 'BiraEstudio'
      @extension.description = 'Genera cajones desde una base seleccionada'
      @extension.version     = '1.0.0'
      @extension.copyright   = '2026 BiraEstudio'
      Sketchup.register_extension(@extension, true)
    end
  end
end
