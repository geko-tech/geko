import { defineConfig, UserConfig } from 'vitepress'
import { generateSidebar,generateSidebarOrdered, wrapSidebarSection } from './scripts/generateSidebar.mts';

export default defineConfig(async () => {
  const referencesSidebar = await generateSidebar({
    scanDir: "docs/projectdescription",
    baseUrl: "/projectdescription/",
  });

  return {
    title: "Geko",
    description: "Command-line tool for managing development infrastructure for Xcode-based projects.",
    head: [['link', { rel: 'icon', href: '/geko/favicon.ico' }]],
    base: '/geko/',
    cleanUrls: true,
    themeConfig: {
      logo: '/logo-nav.png',

      // https://vitepress.dev/reference/default-theme-config
      nav: [
        { text: 'Home', link: '/' },
        { text: 'Guides', link: '/guides' },
        { text: 'ProjectDescription', link: '/projectdescription/structs/Project' }
      ],

      search: {
        provider: 'local'
      },

      sidebar: {
        '/guides/': [
            wrapSidebarSection(
              await generateSidebarOrdered({
                scanDir: "docs/guides/general",
                baseUrl: "/guides/general/",
                useTitleFromFileHeading: true
              }),
              {
                sectionText: "Get Started",
              }
            ),
            {
              text: 'Features',
              items: [
                wrapSidebarSection(
                  await generateSidebarOrdered({
                    scanDir: "docs/guides/features/project-generation",
                    baseUrl: "/guides/features/project-generation/",
                    useTitleFromFileHeading: true
                  }),
                  {
                    sectionText: "Project Generation",
                    collapsed: true,
                    link: "/guides/features/project-generation/"
                  }
                ),
                wrapSidebarSection(
                  await generateSidebarOrdered({
                    scanDir: "docs/guides/features/dependencies",
                    baseUrl: "/guides/features/dependencies/",
                    useTitleFromFileHeading: true
                  }),
                  {
                    sectionText: "Dependencies",
                    collapsed: true,
                    link: "/guides/features/dependencies/"
                  }
                ),
                wrapSidebarSection(
                  await generateSidebarOrdered({
                    scanDir: "docs/guides/features/cache",
                    baseUrl: "/guides/features/cache/",
                    useTitleFromFileHeading: true
                  }),
                  {
                    sectionText: "Build Cache",
                    collapsed: true,
                    link: "/guides/features/cache/"
                  }
                ),
                wrapSidebarSection(
                  await generateSidebarOrdered({
                    scanDir: "docs/guides/features/plugins",
                    baseUrl: "/guides/features/plugins/",
                    useTitleFromFileHeading: true
                  }),
                  {
                    sectionText: "Plugins",
                    collapsed: true,
                    link: "/guides/features/plugins/"
                  }
                ),
                wrapSidebarSection(
                  await generateSidebarOrdered({
                    scanDir: "docs/guides/features/linux",
                    baseUrl: "/guides/features/linux/",
                    useTitleFromFileHeading: true
                  }),
                  {
                    sectionText: "Linux",
                    collapsed: true,
                    link: "/guides/features/linux/"
                  }
                ),
                wrapSidebarSection(
                  await generateSidebarOrdered({
                    scanDir: "docs/guides/features/desktop",
                    baseUrl: "/guides/features/desktop/",
                    useTitleFromFileHeading: true
                  }),
                  {
                    sectionText: "Desktop App",
                    collapsed: true,
                    link: "/guides/features/desktop/"
                  }
                )
              ]
            },
            wrapSidebarSection(
                  await generateSidebarOrdered({
                    scanDir: "docs/guides/commands/",
                    baseUrl: "/guides/commands/",
                    useTitleFromFileHeading: true,
                  }),
                  {
                    sectionText: "Commands",
                  }
            )

          ],
        '/projectdescription/': [
          {
            text: "ProjectDescription",
            items: referencesSidebar
          },
        ]
      },

      socialLinks: [
        { icon: 'github', link: 'https://github.com/geko-tech/geko' }
      ]
    }
  };
});