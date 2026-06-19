# encoding: UTF-8
# autocajon/main.rb — HtmlDialog y callbacks

require 'json'

require File.join(File.dirname(__FILE__), 'store')
require File.join(File.dirname(__FILE__), 'geometria')
require File.join(File.dirname(__FILE__), 'seleccion')

module BiraEstudio
  module AutoCajon
    PLUGIN_DIR = File.expand_path(File.dirname(__FILE__)).freeze
    DIALOG_KEY = 'BiraEstudio.AutoCajon'.freeze

    class Dialog
      @dialog = nil

      class << self
        def show
          @dialog ||= build_dialog
          @dialog.show
          @dialog.bring_to_front if @dialog.visible?
        end

        def start_face_pick
          @dialog ||= build_dialog
          Sketchup.active_model.select_tool(PickBaseTool.new)
        end

        def finish_face_pick(dims)
          @dialog ||= build_dialog
          Store.push_base(@dialog, dims)
        end

        def cancel_face_pick
          @dialog ||= build_dialog
          Store.run_script(@dialog, 'setPickingState(false)')
        end

        def dialog
          @dialog
        end

        def build_dialog
          html_path = File.join(PLUGIN_DIR, 'dialog.html')
          dialog = UI::HtmlDialog.new(
            dialog_title: 'AutoCajon',
            preferences_key: DIALOG_KEY,
            scrollable: true,
            resizable: true,
            width: 350,
            height: 440,
            min_width: 320,
            min_height: 400,
            style: UI::HtmlDialog::STYLE_WINDOW
          )

          dialog.set_file(html_path)

          dialog.add_action_callback('dialog_ready') do |_ctx|
            model = Sketchup.active_model
            Store.push_lista(dialog, model)
            Store.push_base(dialog, nil)
          end

          dialog.add_action_callback('pick_base') do |_ctx|
            Dialog.start_face_pick
          end

          dialog.add_action_callback('generar') do |_ctx, json|
            params = JSON.parse(json)
            model = Sketchup.active_model
            group = Geometria.generar(model, params, Store.base_data)
            if group
              Store.clear_base
              Store.run_script(dialog, 'resetForm()')
              Store.push_lista(dialog, model)
            end
          end

          dialog.add_action_callback('sincronizar') do |_ctx|
            model = Sketchup.active_model
            Store.push_lista(dialog, model)
          end

          dialog.add_action_callback('guardar') do |_ctx|
            model = Sketchup.active_model
            if model.path.empty?
              UI.messagebox('Guarde el modelo con Archivo > Guardar como antes de usar este botón.')
            else
              model.save
              Sketchup.status_text = 'Modelo guardado'
            end
          end

          dialog.add_action_callback('cerrar') do |_ctx|
            dialog.close
          end

          dialog.add_action_callback('seleccionar_cajon') do |_ctx, json|
            payload = JSON.parse(json)
            model = Sketchup.active_model

            if payload['deselect']
              model.selection.clear
              Store.clear_highlight
              Sketchup.status_text = ''
              next
            end

            nombre = payload['nombre'].to_s
            entry = Store.find_by_nombre(model, nombre)

            unless entry
              UI.messagebox("No se encontró el cajón \"#{nombre}\" en el modelo.")
              next
            end

            entity = entry[:entity]
            model.selection.clear
            model.selection.add(entity)
            Store.highlight_entity(entity)
            Sketchup.status_text = "Cajón seleccionado: #{nombre}"
          end

          dialog.set_on_closed do
            Store.clear_highlight
          end

          dialog
        end
      end
    end

    unless file_loaded?(__FILE__)
      cmd = UI::Command.new('AutoCajon') { Dialog.show }
      cmd.tooltip = 'Generar cajones desde una base'
      cmd.status_bar_text = 'Abre el panel AutoCajon para generar cajones'
      cmd.menu_text = 'AutoCajon'

      icon_dir = File.join(PLUGIN_DIR, 'icons')
      cmd.small_icon = File.join(icon_dir, 'autocajon_24.png')
      cmd.large_icon = File.join(icon_dir, 'autocajon_32.png')

      toolbar = UI::Toolbar.new('AutoCajon')
      toolbar.add_item(cmd)
      toolbar.restore

      menu = UI.menu('Plugins').add_submenu('AutoCajon')
      menu.add_item(cmd)

      file_loaded(__FILE__)
    end
  end
end
