// See the Tailwind configuration guide for advanced usage
// https://tailwindcss.com/docs/configuration

let plugin = require('tailwindcss/plugin')

module.exports = {
    daisyui: {
        themes: [
            {
                afterdark: {
                    "primary": "#7B79B5",
                    "secondary": "#ACABD5",
                    "accent": "#fef3c7",
                    "neutral": "#38357F",
                    "base-100": "#201D65",
                    "info": "#7dd3fc",
                    "success": "#a7f3d0",
                    "warning": "#fef08a",
                    "error": "#fca5a5",
                },
                her: {
                    "primary": "#b57979",
                    "secondary": "#d5abab",
                    "accent": "#fef3c7",
                    "neutral": "#7f3535",
                    "base-100": "#651d1d",
                    "info": "#7dd3fc",
                    "success": "#a7f3d0",
                    "warning": "#fef08a",
                    "error": "#fca5a5",
                },
                forest: {
                    "primary": "#4ade80",
                    "secondary": "#86efac",
                    "accent": "#fef3c7",
                    "neutral": "#166534",
                    "base-100": "#052e16",
                    "info": "#7dd3fc",
                    "success": "#a7f3d0",
                    "warning": "#fef08a",
                    "error": "#fca5a5",
                },
                sky: {
                    "primary": "#38bdf8",
                    "secondary": "#7dd3fc",
                    "accent": "#fef3c7",
                    "neutral": "#0c4a6e",
                    "base-100": "#082f49",
                    "info": "#7dd3fc",
                    "success": "#a7f3d0",
                    "warning": "#fef08a",
                    "error": "#fca5a5",
                },
                clays: {
                    "primary": "#d97706",
                    "secondary": "#f59e0b",
                    "accent": "#fef3c7",
                    "neutral": "#92400e",
                    "base-100": "#451a03",
                    "info": "#7dd3fc",
                    "success": "#a7f3d0",
                    "warning": "#fef08a",
                    "error": "#fca5a5",
                },
                stones: {
                    "primary": "#6b7280",
                    "secondary": "#9ca3af",
                    "accent": "#fef3c7",
                    "neutral": "#57534e",
                    "base-100": "#292524",
                    "info": "#7dd3fc",
                    "success": "#a7f3d0",
                    "warning": "#fef08a",
                    "error": "#fca5a5",
                },
            },
            "lofi",
            "black"
        ]
    },
    content: [
        './js/**/*.js',
        '../lib/*_web.ex',
        '../lib/*_web/**/*.*ex'
    ],
    // Tint classes are assembled at runtime -- text-${tint}-500 and friends --
    // so nothing in the source ever contains them for Tailwind to find. Until
    // now they survived only because of literal dummy spans in a few
    // templates, which is why text-red-500 was missing while bg-red-500 was
    // not. Keep this in step with RoomSanctum.Tints.
    safelist: [
        {
            pattern: /^(text|bg|border|ring)-(red|orange|amber|yellow|lime|green|emerald|teal|cyan|sky|blue|indigo|violet|purple|fuchsia|pink|rose|slate|gray|zinc|stone)-(50|100|200|300|400|500|600|700|800|900)$/,
            variants: ['hover'],
        },
    ],
    theme: {
        extend: {},
    },
    plugins: [
        require("daisyui"),
        require('@tailwindcss/forms'),
        plugin(({addVariant}) => addVariant('phx-no-feedback', ['&.phx-no-feedback', '.phx-no-feedback &'])),
        plugin(({addVariant}) => addVariant('phx-click-loading', ['&.phx-click-loading', '.phx-click-loading &'])),
        plugin(({addVariant}) => addVariant('phx-submit-loading', ['&.phx-submit-loading', '.phx-submit-loading &'])),
        plugin(({addVariant}) => addVariant('phx-change-loading', ['&.phx-change-loading', '.phx-change-loading &']))
    ]
}
