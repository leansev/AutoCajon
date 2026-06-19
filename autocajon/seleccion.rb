# encoding: UTF-8
# autocajon/seleccion.rb — Tool de clic en cara (pick_base)

module BiraEstudio
  module AutoCajon
    class PickBaseTool
      PICK_APERTURE = 12

      def initialize
        @completed = false
      end

      def activate
        Sketchup.status_text = 'Click en la cara base del vano (1 clic). Esc = cancelar.'
        view = Sketchup.active_model.active_view
        view.invalidate if view
      end

      def deactivate(_view)
        Sketchup.status_text = ''
        Dialog.cancel_face_pick unless @completed
      end

      def onCancel(_reason, _view)
        @completed = true
        Sketchup.active_model.select_tool(nil)
        Dialog.cancel_face_pick
      end

      def onLButtonDown(_flags, x, y, view)
        model = Sketchup.active_model
        face = pick_face(view, x, y)

        unless face
          UI.messagebox('Seleccione una cara valida.')
          return
        end

        dims = face_dimensions_mm(face)
        unless dims
          UI.messagebox('No se pudieron leer las dimensiones de la cara.')
          return
        end

        orient = face_orientation(face)
        unless orient
          UI.messagebox('No se pudo determinar la orientacion de la cara.')
          return
        end

        @completed = true
        Store.set_base(orient)
        model.select_tool(nil)
        Dialog.finish_face_pick(dims)
        Sketchup.status_text = "Base: #{dims[:largo]} x #{dims[:ancho]} mm"
      end

      def pick_face(view, x, y)
        ph = view.pick_helper
        ph.do_pick(x, y, PICK_APERTURE)

        face = ph.picked_face
        return face if face

        (0...ph.count).each do |i|
          path = ph.path_at(i)
          next unless path

          path.each do |entity|
            return entity if entity.is_a?(Sketchup::Face)
          end
        end

        nil
      end

      def face_dimensions_mm(face)
        bb = face.bounds
        return nil if bb.empty?

        d1 = bb.width.to_mm
        d2 = bb.height.to_mm
        d3 = bb.depth.to_mm
        sorted = [d1, d2, d3].sort.reverse
        largo = sorted[0]
        ancho = sorted[1]
        return nil if largo <= 0 || ancho <= 0

        { largo: largo.round, ancho: ancho.round }
      end

      def face_orientation(face)
        bb = face.bounds
        normal = face.normal
        return nil if normal.length < 1.0e-6

        z_axis = normal.normalize
        z_axis.reverse! if z_axis.z < 0

        longest = face.edges.max_by { |e| e.length }
        return nil unless longest

        x_axis = longest.start.position.vector_to(longest.end.position)
        scale = x_axis.dot(z_axis)
        x_axis = Geom::Vector3d.new(
          x_axis.x - z_axis.x * scale,
          x_axis.y - z_axis.y * scale,
          x_axis.z - z_axis.z * scale
        )
        return nil if x_axis.length < 1.0e-6

        x_axis.normalize!
        y_axis = z_axis.cross(x_axis)
        return nil if y_axis.length < 1.0e-6

        y_axis.normalize!

        {
          origin: bb.min,
          x_axis: x_axis,
          y_axis: y_axis,
          z_axis: z_axis
        }
      end
    end
  end
end
