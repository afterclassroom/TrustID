/** @type {import('tailwindcss').Config} */
module.exports = {
  content: [
    './app/views/**/*.html.erb',
    './app/helpers/**/*.rb',
    './app/assets/javascripts/**/*.js',
    './app/components/**/*.{rb,erb,html}',
  ],
  theme: {
    extend: {},
  },
  plugins: [],
}
