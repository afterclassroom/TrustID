# Override tailwindcss-rails build to prevent incompatible CSS syntax
# Tailwind CSS v4 generates modern syntax like @media (width >= 40rem)
# which is incompatible with SassC in Rails asset pipeline

namespace :tailwindcss do
  # Override build task to use pre-processed file
  task :build do
    puts "⚠️  Using pre-built Tailwind CSS (skipping build to avoid SassC compatibility issues)"
    
    # Fix modern CSS syntax to be compatible with SassC
    tailwind_file = Rails.root.join("app/assets/builds/tailwind.css")
    if File.exist?(tailwind_file)
      content = File.read(tailwind_file)
      
      # Replace modern media query syntax with legacy syntax
      content.gsub!(/\(width >= ([^)]+)\)/, '(min-width: \1)')
      content.gsub!(/\(width <= ([^)]+)\)/, '(max-width: \1)')
      content.gsub!(/\(height >= ([^)]+)\)/, '(min-height: \1)')
      content.gsub!(/\(height <= ([^)]+)\)/, '(max-height: \1)')
      
      # Remove modern CSS color syntax that's incompatible with SassC
      # Replace rgb(from ...) with fallback
      content.gsub!(/rgb\(from [^)]+\)/, 'rgb(0, 0, 0)')
      content.gsub!(/color:\s*rgb\(from [^)]+\)/, 'color: inherit')
      
      # Remove CSS feature detection queries that cause SassC errors
      content.gsub!(/\(color:\s*rgb\([^)]*\)\)/, '(color: #000)')
      content.gsub!(/\(-moz-orient:\s*inline\)\s*and\s*\(not\s*\([^)]*rgb\([^)]*\)[^)]*\)\)/, '(-moz-orient: inline)')
      
      File.write(tailwind_file, content)
      puts "✅ Fixed Tailwind CSS syntax for SassC compatibility"
    else
      puts "⚠️  Tailwind CSS file not found at #{tailwind_file}"
    end
  end
  
  # Skip watch task in production
  task :watch do
    puts "Skipping Tailwind watch (production mode)"
  end
end
