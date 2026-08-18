import {
  REPOSITORY_FORMAT_VALUES,
  SETUP_SECTION_INSTALL,
  SETUP_SECTION_PUBLISH,
  SETUP_TOOLS,
} from 'ee/packages_and_registries/artifact_registry/constants';
import { setupSnippetSections } from 'ee/packages_and_registries/artifact_registry/repositories/detail/setup_instructions/snippets';
import { buildRepositoryClientUrl } from 'ee/packages_and_registries/artifact_registry/utils';
import { CLIENT_BASE_URL, SLUG } from '../../../mock_data';

const NAME = 'my-repository';
const SECTIONS = [SETUP_SECTION_INSTALL, SETUP_SECTION_PUBLISH];

const urlFor = (format) =>
  buildRepositoryClientUrl({ clientBaseUrl: CLIENT_BASE_URL, slug: SLUG, format, name: NAME });

const build = ({ format, tool, section }) =>
  setupSnippetSections({ format, tool, section, name: NAME, repositoryUrl: urlFor(format) });

const codeOf = (sections) =>
  sections.flatMap(({ blocks }) => blocks.map(({ code }) => code).filter(Boolean));

// Every format, tool, and section the selector can put on screen.
const everyCombination = REPOSITORY_FORMAT_VALUES.flatMap((format) =>
  SETUP_TOOLS[format].flatMap(({ value: tool }) =>
    SECTIONS.map((section) => [format, tool, section]),
  ),
);

describe('setupSnippetSections', () => {
  describe('what a format, tool, and section produce', () => {
    it.each(everyCombination)(
      'gives a %s repository on %s a %s section with at least one command',
      (format, tool, section) => {
        expect(codeOf(build({ format, tool, section }))).not.toHaveLength(0);
      },
    );

    it.each(everyCombination)(
      'follows the %s / %s / %s content with a setup section a client needs to reach the repository',
      (format, tool, section) => {
        const sections = build({ format, tool, section });

        expect(sections).toHaveLength(2);
        expect(sections[1].heading).toEqual(expect.any(String));
      },
    );

    it('reads the repository name back in the Maven coordinates that identify the repository', () => {
      const [, setup] = build({
        format: 'MAVEN',
        tool: 'maven',
        section: SETUP_SECTION_PUBLISH,
      });

      expect(setup.blocks[0].code).toContain(`<id>${NAME}</id>`);
    });
  });

  describe('the repository URL every snippet is composed on', () => {
    it.each(everyCombination)(
      'addresses this repository, not a placeholder, for %s on %s (%s)',
      (format, tool, section) => {
        const url = urlFor(format);
        const withUrl = codeOf(build({ format, tool, section })).filter(
          (code) => code.includes(url) || code.includes(url.replace('https://', '')),
        );

        expect(withUrl).not.toHaveLength(0);
      },
    );

    it('strips the scheme where a container reference cannot carry one', () => {
      const [pull] = codeOf(
        build({ format: 'DOCKER', tool: 'docker', section: SETUP_SECTION_INSTALL }),
      );

      expect(pull).toBe(
        'docker pull artifact-registry.example.com/acme/container/my-repository/image:tag',
      );
    });

    it('signs in against the registry host alone, not the repository path', () => {
      const [, signIn] = codeOf(
        build({ format: 'OCI', tool: 'podman', section: SETUP_SECTION_INSTALL }),
      );

      expect(signIn).toContain('podman login artifact-registry.example.com --username');
    });
  });

  describe('switching the build tool', () => {
    it.each(REPOSITORY_FORMAT_VALUES)(
      'gives a %s repository different commands for each of its tools',
      (format) => {
        const perTool = SETUP_TOOLS[format].map(({ value: tool }) =>
          JSON.stringify(codeOf(build({ format, tool, section: SETUP_SECTION_PUBLISH }))),
        );

        expect(new Set(perTool).size).toBe(perTool.length);
      },
    );

    it('offers Gradle its own DSL rather than repeating the Maven command', () => {
      const groovy = codeOf(
        build({ format: 'MAVEN', tool: 'gradle_groovy', section: SETUP_SECTION_PUBLISH }),
      );
      const kotlin = codeOf(
        build({ format: 'MAVEN', tool: 'gradle_kotlin', section: SETUP_SECTION_PUBLISH }),
      );

      expect(groovy).toContain('gradle publish');
      expect(kotlin).toContain('gradle publish');
      expect(groovy.join()).not.toContain('mvn');
    });

    it.each([SETUP_SECTION_INSTALL, SETUP_SECTION_PUBLISH])(
      'varies only the DSL between the Gradle tools in %s, never the Gradle install',
      (section) => {
        const forTool = (tool) => codeOf(build({ format: 'MAVEN', tool, section }));

        expect(forTool('gradle_groovy').join()).not.toContain('./gradlew');
        expect(forTool('gradle_kotlin').join()).not.toContain('./gradlew');
      },
    );

    it('publishes yarn through the Berry npm plugin, not the Classic `yarn publish`', () => {
      const [publish, registry] = codeOf(
        build({ format: 'NPM', tool: 'yarn', section: SETUP_SECTION_PUBLISH }),
      );

      expect(publish).toBe('yarn npm publish');
      expect(registry).toContain('npmScopes:');
    });
  });

  describe('credentials', () => {
    it.each(everyCombination)(
      'names a token placeholder rather than carrying a credential for %s on %s (%s)',
      (format, tool, section) => {
        const body = codeOf(build({ format, tool, section })).join('\n');

        expect(body).not.toMatch(/glpat-|--password[= ](?!-stdin)|-p\s+\S|Bearer\s/);
      },
    );

    it.each(everyCombination)(
      'reads the token from the environment wherever %s on %s (%s) authenticates',
      (format, tool, section) => {
        const body = codeOf(build({ format, tool, section }));
        const authenticating = body.filter((code) => /token|Token|GITLAB_TOKEN/.test(code));

        authenticating.forEach((code) => {
          expect(code).toMatch(/\$\{GITLAB_TOKEN\}|System\.getenv\((["'])GITLAB_TOKEN\1\)/);
        });
      },
    );
  });

  describe('a repository name carrying XML metacharacters', () => {
    const HOSTILE = 'a</id><url>https://evil.example/</url><id>b';

    const hostileSections = (section) =>
      setupSnippetSections({
        format: 'MAVEN',
        tool: 'maven',
        section,
        name: HOSTILE,
        repositoryUrl: urlFor('MAVEN'),
      });

    it.each(SECTIONS)('opens no new element anywhere in the %s XML', (section) => {
      const xml = codeOf(hostileSections(section)).filter((code) => code.startsWith('<'));

      expect(xml).not.toHaveLength(0);
      xml.forEach((code) => expect(code).not.toContain('<url>https://evil.example/</url>'));
    });

    it.each(SECTIONS)('escapes the name where %s embeds it', (section) => {
      const withName = codeOf(hostileSections(section)).filter((code) => code.includes('<id>'));

      expect(withName).not.toHaveLength(0);
      withName.forEach((code) => expect(code).toContain('&lt;url&gt;'));
    });

    it.each(SECTIONS)('keeps one id element per repository block in %s', (section) => {
      codeOf(hostileSections(section))
        .filter((code) => code.includes('<id>'))
        .forEach((code) => {
          expect(code.match(/<id>/g)).toHaveLength(1);
        });
    });
  });

  describe('when the guidance cannot be composed', () => {
    it('yields no sections without a repository URL, rather than guidance with a hole in it', () => {
      expect(
        setupSnippetSections({
          format: 'MAVEN',
          tool: 'maven',
          section: SETUP_SECTION_INSTALL,
          name: NAME,
          repositoryUrl: null,
        }),
      ).toEqual([]);
    });

    it('yields no sections without a repository name', () => {
      expect(
        setupSnippetSections({
          format: 'MAVEN',
          tool: 'maven',
          section: SETUP_SECTION_INSTALL,
          name: '',
          repositoryUrl: urlFor('MAVEN'),
        }),
      ).toEqual([]);
    });

    it('yields no sections for a format it carries no guidance for', () => {
      expect(
        setupSnippetSections({
          format: 'CONAN',
          tool: 'conan',
          section: SETUP_SECTION_INSTALL,
          name: NAME,
          repositoryUrl: urlFor('MAVEN'),
        }),
      ).toEqual([]);
    });
  });
});
