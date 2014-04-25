class SeedDump
  module Environment
    def lchomp(base, arg)
      base.to_s.reverse.chomp(arg.to_s.reverse).reverse
    end

    def possible_models
      ([Rails.application] + Rails::Engine.subclasses.collect(&:instance)).flat_map do |app|
        (app.paths['app/models'].to_a + app.config.autoload_paths).collect do |load_path|
          Dir.glob(app.root.join(load_path)).collect do |load_dir|
            Dir.glob(load_dir + '/**/*.rb').collect do |filename|
              # app/models/module/class.rb => module/class.rb => module/class => Module::Class
              lchomp(filename, "#{app.root.join(load_dir)}/").chomp('.rb').camelize
            end
          end
        end
      end.flatten.reject { |m| m.starts_with?('Concerns::') }.collect { |m| m.constantize }
    end

    def dump_using_environment(env = {})
      Rails.application.eager_load!

      models = if env['MODEL'] || env['MODELS']
                 (env['MODEL'] || env['MODELS']).split(',').collect {|x| x.strip.underscore.singularize.camelize.constantize }
               else
                 possible_models.select do |model|
                   (model.to_s != 'ActiveRecord::SchemaMigration') && \
                    model.table_exists? && \
                    model.exists?
                 end
               end

      append = (env['APPEND'] == 'true')

      models.each do |model|
        model = model.limit(env['LIMIT'].to_i) if env['LIMIT']

        SeedDump.dump(model,
                      append: append,
                      batch_size: (env['BATCH_SIZE'] ? env['BATCH_SIZE'].to_i : nil),
                      exclude: (env['EXCLUDE'] ? env['EXCLUDE'].split(',').map {|e| e.strip.to_sym} : nil),
                      file: (env['FILE'] || 'db/seeds.rb'))

        append = true
      end
    end
  end
end

