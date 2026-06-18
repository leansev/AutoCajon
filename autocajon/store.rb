# encoding: UTF-8
# autocajon/store.rb — Persistencia y lista de cajones

require 'json'

module BiraEstudio
  module AutoCajon
    ATTRIBUTE_DICT = 'autocajon'.freeze
    COUNTER_KEY    = 'counter'.freeze
    HIGHLIGHT_MAT  = 'AutoCajon_resaltado'.freeze

    class Store
      @base_data = nil
      @highlight_entity = nil
      @view_observer = nil

      class << self
        attr_accessor :base_data, :highlight_entity

        # --- Base seleccionada (cara) ---

        def set_base(data)
          @base_data = data
        end

        def clear_base
          @base_data = nil
        end

        def base_ready?
          !@base_data.nil?
        end

        # --- Nombres correlativos ---

        def index_to_letters(index)
          result = ''
          n = index
          loop do
            result = (65 + (n % 26)).chr + result
            n = n / 26 - 1
            break if n < 0
          end
          result
        end

        def next_cajon_name(model)
          counter = model.get_attribute(ATTRIBUTE_DICT, COUNTER_KEY, 0).to_i
          name = "Cajón#{index_to_letters(counter)}"
          model.set_attribute(ATTRIBUTE_DICT, COUNTER_KEY, counter + 1)
          name
        end

        # --- Atributos en grupos ---

        def write_attrs(group, attrs)
          attrs.each do |key, value|
            group.set_attribute(ATTRIBUTE_DICT, key.to_s, value)
          end
        end

        def read_attrs(group)
          return nil unless group.is_a?(Sketchup::Group)
          return nil unless group.attribute_dictionaries && group.attribute_dictionaries[ATTRIBUTE_DICT]

          dict = group.attribute_dictionary(ATTRIBUTE_DICT)
          nombre = dict['nombre'].to_s
          return nil if nombre.empty?

          {
            nombre: nombre,
            ancho: dict['ancho'].to_f,
            alto: dict['alto'].to_f,
            prof: dict['prof'].to_f,
            espesor: dict['espesor'].to_i,
            corredera: dict['corredera'].to_s
          }
        end

        def mark_parent_group(group, attrs)
          write_attrs(group, attrs)
          group.name = attrs[:nombre] if attrs[:nombre]
        end

        # --- Escaneo del modelo ---

        def collect_cajones(model)
          found = []
          scan_entities(model.entities, found)
          found.sort_by { |c| c[:nombre] }
        end

        def scan_entities(entities, found)
          entities.each do |entity|
            next unless entity.is_a?(Sketchup::Group)

            attrs = read_attrs(entity)
            found << attrs.merge(entity: entity) if attrs

            scan_entities(entity.entities, found)
          end
        end

        def find_by_nombre(model, nombre)
          collect_cajones(model).find { |c| c[:nombre] == nombre }
        end

        def lista_json(model)
          collect_cajones(model).map do |c|
            {
              nombre: c[:nombre],
              ancho: c[:ancho],
              alto: c[:alto],
              prof: c[:prof],
              espesor: c[:espesor],
              corredera: c[:corredera]
            }
          end
        end

        def push_lista(dialog, model)
          json = JSON.generate(lista_json(model))
          dialog.execute_script("setLista(#{json.inspect})")
        rescue StandardError => e
          puts "[AutoCajon] push_lista: #{e.message}"
        end

        def push_base(dialog, data)
          if data
            json = JSON.generate(data)
            dialog.execute_script("setBase(#{json.inspect})")
          else
            dialog.execute_script('setBase(null)')
          end
        rescue StandardError => e
          puts "[AutoCajon] push_base: #{e.message}"
        end

        # --- Resaltado naranja ---

        HIGHLIGHT_COLOR = Sketchup::Color.new(255, 140, 0)
        BOX_EDGES = [
          [0, 1], [1, 3], [3, 2], [2, 0],
          [4, 5], [5, 7], [7, 6], [6, 4],
          [0, 4], [1, 5], [2, 6], [3, 7]
        ].freeze

        def clear_highlight
          entity = @highlight_entity
          return unless entity

          if entity.valid?
            mat = entity.material
            entity.material = nil if mat && mat.name == HIGHLIGHT_MAT
          end
          @highlight_entity = nil
          detach_view_observer
        end

        def highlight_entity(entity)
          clear_highlight
          return unless entity && entity.valid?

          model = Sketchup.active_model
          mat = model.materials[HIGHLIGHT_MAT]
          unless mat
            mat = model.materials.add(HIGHLIGHT_MAT)
          end
          mat.color = HIGHLIGHT_COLOR
          mat.alpha = 0.35

          entity.material = mat
          @highlight_entity = entity
          attach_view_observer
          invalidate_view
        end

        def draw_highlight(view)
          entity = @highlight_entity
          return unless entity && entity.valid?

          bounds = entity.bounds
          return if bounds.empty?

          view.line_width = 3
          view.drawing_color = HIGHLIGHT_COLOR
          corners = (0..7).map { |i| bounds.corner(i) }
          BOX_EDGES.each do |a, b|
            view.draw(GL_LINES, corners[a], corners[b])
          end
        end

        def attach_view_observer
          return if @view_observer

          @view_observer = HighlightViewObserver.new
          Sketchup.active_model.active_view.add_observer(@view_observer)
        end

        def detach_view_observer
          return unless @view_observer

          view = Sketchup.active_model.active_view rescue nil
          view.remove_observer(@view_observer) if view
          @view_observer = nil
        end

        def invalidate_view
          view = Sketchup.active_model.active_view rescue nil
          view.invalidate if view
        end
      end
    end

    class HighlightViewObserver < Sketchup::ViewObserver
      def draw(view)
        Store.draw_highlight(view)
      end
    end
  end
end
