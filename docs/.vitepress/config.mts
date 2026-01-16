import { defineConfig } from 'vitepress'

// https://vitepress.dev/reference/site-config
export default defineConfig({
  title: "Geko",
  description: "Geko is a CLI utility that provides development infrastructure for Xcode based projects.",
  head: [['link', { rel: 'icon', href: '/geko/favicon.ico' }]],
  base: '/geko/',
  cleanUrls: true,
  themeConfig: {
    logo: '/logo-nav.png',

    // https://vitepress.dev/reference/default-theme-config
    nav: [
      { text: 'Home', link: '/' },
      { text: 'Guides', link: '/main-description' }
    ],

    sidebar: [
      {
        text: 'Get Started',
        items: [
          { text: 'Install Geko', link: '/general/setup' },
          { text: 'How to use Geko', link: '/general/usage' }
        ],
      },
      {
        text: 'Features',
        items: [
          {
            text: 'Project Generation',
            collapsed: true,
            items: [
              { text: 'Overview', link: '/features/project-generation/' },
              { text: 'Directory structure', link: '/features/project-generation/dir_structure' },
              { text: 'Editing', link: '/features/project-generation/editing' },
              { text: 'Buildable folders', link: '/features/project-generation/buildable_folders' },
              { text: 'Linking', link: '/features/project-generation/linking' },
              { text: 'Cocoapods Multiplatform', link: '/features/project-generation/cocoapods_multiplatform' },
              { text: 'ProjectDescriptionHelpers', link: '/features/project-generation/project_description_helpers' }
            ]
          },
          {
            text: 'Build Cache',
            collapsed: true,
            items: [
              { text: 'Overview', link: '/features/cache/' },
              { text: 'Setup', link: '/features/cache/cache_setup' },
              { text: 'Usage', link: '/features/cache/cache_usage' },
              { text: 'Debug', link: '/features/cache/cache_debug' },
            ]
          },
          {
            text: 'Plugins',
            collapsed: true,
            items: [
              { text: 'Overview', link: '/features/plugins/' },
              { text: 'ProjectDescriptionHelper', link: '/features/plugins/projectdescriptionhelpers_plugin' },
              { text: 'Templates', link: '/features/plugins/templates_plugin' },
              { text: 'WorkspaceMapper', link: '/features/plugins/workspacemapper_plugin' },
              { text: 'Executable', link: '/features/plugins/executable_plugin' },
              { text: 'Plugin usage', link: '/features/plugins/plugins_connection' },
              { text: 'OfficialPlugins', items: [
                { text: 'ImpactAnalysis', link: '/features/plugins/OfficialPlugins/ImpactAnalysis' }
              ]}
            ]
          },
          {
            text: 'Linux',
            collapsed: true,
            items: [
              { text: 'Overview', link: '/features/linux/' },
            ]
          },
          {
            text: 'Desktop App',
            collapsed: true,
            items: [
              { text: 'Overview', link: '/features/desktop/' },
              { text: 'Install', link: '/features/desktop/desktop_install' },
              { text: 'Setup', link: '/features/desktop/desktop_setup' },
              { text: 'Configuration', link: '/features/desktop/desktop_settings' },
              { text: 'Shortcuts', link: '/features/desktop/desktop_shortcuts' },
              { text: 'Features & Issues', link: '/features/desktop/desktop_other' },
            ]
          }
        ]
      },
      {
        text: 'Commands',
        items: [
          { text: 'Clean', link: '/commands/clean' },
          { text: 'Inspect', link: '/commands/inspect' },
        ]
      }
    ],

    socialLinks: [
      { icon: 'github', link: 'https://github.com/geko-tech/geko' }
    ]
  }
})
