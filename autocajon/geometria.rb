# encoding: UTF-8
# autocajon/geometria.rb — Cálculo y dibujo de cajones

module BiraEstudio
  module AutoCajon
    module Geometria
      module_function

      def descuento_corredera(corredera)
        corredera.to_s == 'telescopica' ? 13 : 6
      end

      def validar_dimensiones(ancho_vano, profundidad, alto, espesor, corredera)
        desc = descuento_corredera(corredera)
        esp  = espesor.to_i
        wc   = ancho_vano.to_f - 2 * desc
        largo_ft = wc - 2 * esp
        prof_base = profundidad.to_f - 2 * esp

        errors = []
        errors << 'Ancho de vano insuficiente' if wc <= 0
        errors << 'Largo interior insuficiente' if largo_ft <= 0
        errors << 'Profundidad base insuficiente' if prof_base <= 0
        errors << 'Alto debe ser mayor a 0' if alto.to_f <= 0
        errors << 'Alto insuficiente para corredera oculta (mín. 13 mm)' if corredera.to_s == 'oculta' && alto.to_f <= 12

        {
          valid: errors.empty?,
          errors: errors,
          desc: desc,
          esp: esp,
          wc: wc,
          largo_ft: largo_ft,
          prof_base: prof_base
        }
      end

      def generar(model, params, base_data)
        calc = validar_dimensiones(
          params['ancho_vano'],
          params['profundidad'],
          params['alto'],
          params['espesor'],
          params['corredera']
        )

        unless calc[:valid]
          UI.messagebox("Error:\n#{calc[:errors].join("\n")}")
          return nil
        end

        unless base_data
          UI.messagebox('Seleccione una base antes de generar.')
          return nil
        end

        nombre = Store.next_cajon_name(model)
        dims = {
          wc: calc[:wc],
          prof: params['profundidad'].to_f,
          alto: params['alto'].to_f,
          largo_ft: calc[:largo_ft],
          prof_base: calc[:prof_base],
          esp: calc[:esp],
          desc: calc[:desc],
          corredera: params['corredera'].to_s
        }

        group = nil
        model.start_operation("AutoCajon #{nombre}", true)
        begin
          group = dibujar_cajon(model, dims, base_data, nombre)
          attrs = {
            nombre: nombre,
            ancho: params['ancho_vano'].to_f,
            alto: params['alto'].to_f,
            prof: params['profundidad'].to_f,
            espesor: params['espesor'].to_i,
            corredera: params['corredera'].to_s
          }
          Store.mark_parent_group(group, attrs)
          model.commit_operation
        rescue StandardError => e
          model.abort_operation
          UI.messagebox("Error al generar cajón:\n#{e.message}")
          puts "[AutoCajon] generar: #{e.message}\n#{e.backtrace.join("\n")}"
          return nil
        end

        group
      end

      def dibujar_cajon(model, dims, base_data, nombre)
        parent = model.active_entities.add_group
        parent.name = nombre

        tr = build_transform(base_data, dims)
        parent.transformation = tr

        esp = dims[:esp].mm
        wc = dims[:wc].mm
        prof = dims[:prof].mm
        alto = dims[:alto].mm
        largo_ft = dims[:largo_ft].mm
        prof_base = dims[:prof_base].mm

        if dims[:corredera].to_s == 'oculta'
          z_oculta = 12.mm
          z_frente = z_oculta
          z_base = z_oculta
          alto_frente = alto - 12.mm
        else
          z_frente = 0
          z_base = 0
          alto_frente = alto
        end

        # Lateral izquierdo: esp x prof x alto, X[0..esp]
        crear_pieza(parent.entities, 'Lateral izq', 0, 0, 0, esp, prof, alto)

        # Lateral derecho: esp x prof x alto, X[Wc-esp..Wc]
        crear_pieza(parent.entities, 'Lateral der', wc - esp, 0, 0, esp, prof, alto)

        # Frente: borde superior alineado con laterales; oculta arranca en Z=12
        crear_pieza(parent.entities, 'Frente', esp, 0, z_frente, largo_ft, esp, alto_frente)

        # Trasera: igual que frente en altura y Z
        crear_pieza(parent.entities, 'Trasera', esp, prof - esp, z_frente, largo_ft, esp, alto_frente)

        # Base: oculta arranca en Z=12; telescópica en Z=0
        crear_pieza(parent.entities, 'Base', esp, esp, z_base, largo_ft, prof_base, esp)

        reset_materials(parent)
        parent
      end

      def reset_materials(entity)
        return unless entity

        entity.material = nil if entity.respond_to?(:material=)
        entity.back_material = nil if entity.respond_to?(:back_material=)
        return unless entity.respond_to?(:entities)

        entity.entities.each { |child| reset_materials(child) }
      end

      def crear_pieza(entities, nombre, x, y, z, dx, dy, dz)
        g = entities.add_group
        g.name = nombre
        add_box(g.entities, x, y, z, dx, dy, dz)
        orient_faces_outward(g)
        g
      end

      def orient_faces_outward(group)
        bb = group.bounds
        return if bb.empty?

        center = bb.center
        group.entities.grep(Sketchup::Face).each do |face|
          outward = center.vector_to(face.bounds.center)
          next if outward.length < 1.0e-9

          face.reverse! if face.normal.dot(outward) < 0
        end
      end

      def add_box(entities, x, y, z, dx, dy, dz)
        p0 = [x, y, z]
        p1 = [x + dx, y, z]
        p2 = [x + dx, y + dy, z]
        p3 = [x, y + dy, z]
        p4 = [x, y, z + dz]
        p5 = [x + dx, y, z + dz]
        p6 = [x + dx, y + dy, z + dz]
        p7 = [x, y + dy, z + dz]

        entities.add_face(p0, p1, p2, p3)
        entities.add_face(p4, p5, p6, p7)
        entities.add_face(p0, p1, p5, p4)
        entities.add_face(p1, p2, p6, p5)
        entities.add_face(p2, p3, p7, p6)
        entities.add_face(p3, p0, p4, p7)
      end

      def build_transform(base_data, dims)
        origin = base_data[:origin]
        x_axis = base_data[:x_axis]
        y_axis = base_data[:y_axis]
        z_axis = base_data[:z_axis]

        offset = origin.offset(z_axis, 10.mm)
        Geom::Transformation.axes(offset, x_axis, y_axis, z_axis)
      end
    end
  end
end
