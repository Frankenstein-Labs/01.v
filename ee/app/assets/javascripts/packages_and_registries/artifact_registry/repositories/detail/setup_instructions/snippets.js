import { escape } from 'lodash-es';
import { s__ } from '~/locale';
import { withoutScheme } from '../../../utils';
import {
  REPOSITORY_FORMAT_DOCKER,
  REPOSITORY_FORMAT_MAVEN,
  REPOSITORY_FORMAT_NPM,
  REPOSITORY_FORMAT_OCI,
  SETUP_SECTION_INSTALL,
  SETUP_TOOL_GRADLE_GROOVY,
  SETUP_TOOL_GRADLE_KOTLIN,
  SETUP_TOOL_PNPM,
  SETUP_TOOL_PODMAN,
  SETUP_TOOL_YARN,
} from '../../../constants';

/* eslint-disable no-template-curly-in-string */
const TOKEN_PLACEHOLDER = '${GITLAB_TOKEN}';
const PLACEHOLDER_USERNAME = '${GITLAB_USERNAME}';
/* eslint-enable no-template-curly-in-string */

const PLACEHOLDER_GROUP_ID = 'com.company';
const PLACEHOLDER_ARTIFACT_ID = 'app';
const PLACEHOLDER_VERSION = '1.0.0';
const PLACEHOLDER_SCOPE = 'scope';
const PLACEHOLDER_PACKAGE = '@scope/package';
const PLACEHOLDER_IMAGE = 'image:tag';

const YARN_BERRY_PUBLISH_VIA_NPM_PLUGIN = 'yarn npm publish';

const i18n = {
  repositorySetup: s__('ArtifactRegistry|Repository setup'),
  registrySetup: s__('ArtifactRegistry|Registry setup'),
  copyDependency: s__('ArtifactRegistry|Copy the dependency declaration'),
  copyInstallCommand: s__('ArtifactRegistry|Copy the install command'),
  copyPublishCommand: s__('ArtifactRegistry|Copy the publish command'),
  copyDistribution: s__('ArtifactRegistry|Copy the distribution management configuration'),
  copyRepositoryConfig: s__('ArtifactRegistry|Copy the repository configuration'),
  copyAuthConfig: s__('ArtifactRegistry|Copy the authentication configuration'),
  copyRegistryConfig: s__('ArtifactRegistry|Copy the registry configuration'),
  copyPullCommand: s__('ArtifactRegistry|Copy the pull command'),
  copyPushCommand: s__('ArtifactRegistry|Copy the push command'),
  copySignInCommand: s__('ArtifactRegistry|Copy the sign-in command'),
  installCommand: s__('ArtifactRegistry|Install command:'),
  publishCommand: s__('ArtifactRegistry|Publish command:'),
  mavenDependency: s__(
    'ArtifactRegistry|Copy and paste this inside your %{codeStart}pom.xml%{codeEnd} %{codeStart}dependencies%{codeEnd} block:',
  ),
  mavenDistribution: s__('ArtifactRegistry|Add this to your %{codeStart}pom.xml%{codeEnd} file:'),
  mavenRepository: s__(
    "ArtifactRegistry|If you haven't already, add the configuration below to your %{codeStart}pom.xml%{codeEnd} file:",
  ),
  mavenAuthentication: s__(
    'ArtifactRegistry|Authenticate with a token in your %{codeStart}settings.xml%{codeEnd} file:',
  ),
  gradleGroovyDependency: s__(
    'ArtifactRegistry|Add the dependency to your %{codeStart}build.gradle%{codeEnd} file:',
  ),
  gradleGroovyRepository: s__(
    'ArtifactRegistry|Add the repository to your %{codeStart}build.gradle%{codeEnd} file:',
  ),
  gradleKotlinDependency: s__(
    'ArtifactRegistry|Add the dependency to your %{codeStart}build.gradle.kts%{codeEnd} file:',
  ),
  gradleKotlinRepository: s__(
    'ArtifactRegistry|Add the repository to your %{codeStart}build.gradle.kts%{codeEnd} file:',
  ),
  npmrc: s__('ArtifactRegistry|Add this to your %{codeStart}.npmrc%{codeEnd} file:'),
  yarnrc: s__('ArtifactRegistry|Add this to your %{codeStart}.yarnrc.yml%{codeEnd} file:'),
  pullImage: s__('ArtifactRegistry|Pull an image:'),
  pushImage: s__('ArtifactRegistry|Push an image:'),
  signIn: s__('ArtifactRegistry|Sign in to the registry:'),
};

const hostOf = (url) => withoutScheme(url).split('/')[0];

/* eslint-disable @gitlab/require-i18n-strings -- Snippet bodies are code, not interface copy. */

const gradleSections = ({ tool, section, repositoryUrl }) => {
  const kotlin = tool === SETUP_TOOL_GRADLE_KOTLIN;
  const coordinates = `${PLACEHOLDER_GROUP_ID}:${PLACEHOLDER_ARTIFACT_ID}:${PLACEHOLDER_VERSION}`;

  return [
    {
      blocks: [
        section === SETUP_SECTION_INSTALL
          ? {
              text: kotlin ? i18n.gradleKotlinDependency : i18n.gradleGroovyDependency,
              code: kotlin ? `implementation("${coordinates}")` : `implementation '${coordinates}'`,
              copyText: i18n.copyDependency,
            }
          : {
              text: i18n.publishCommand,
              code: 'gradle publish',
              copyText: i18n.copyPublishCommand,
            },
      ],
    },
    {
      heading: i18n.repositorySetup,
      blocks: [
        {
          text: kotlin ? i18n.gradleKotlinRepository : i18n.gradleGroovyRepository,
          code: kotlin
            ? `maven {
  url = uri("${repositoryUrl}")
  credentials(HttpHeaderCredentials::class) {
    name = "Private-Token"
    value = System.getenv("GITLAB_TOKEN")
  }
  authentication {
    create<HttpHeaderAuthentication>("header")
  }
}`
            : `maven {
  url '${repositoryUrl}'
  credentials(HttpHeaderCredentials) {
    name = 'Private-Token'
    value = System.getenv('GITLAB_TOKEN')
  }
  authentication {
    header(HttpHeaderAuthentication)
  }
}`,
          copyText: i18n.copyRepositoryConfig,
        },
      ],
    },
  ];
};

const mavenSections = ({ tool, section, name, repositoryUrl }) => {
  if (tool === SETUP_TOOL_GRADLE_GROOVY || tool === SETUP_TOOL_GRADLE_KOTLIN) {
    return gradleSections({ tool, section, repositoryUrl });
  }

  // The reader pastes these blocks into their own pom.xml and settings.xml, so a
  // repository name carrying an XML metacharacter would inject elements into a build
  // file rather than break a page. Artifact Registry restricts the name charset today
  // (REPOSITORY_NAME_PATTERN), which this does not take on trust.
  const xmlName = escape(name);
  const xmlUrl = escape(repositoryUrl);

  return [
    {
      blocks:
        section === SETUP_SECTION_INSTALL
          ? [
              {
                text: i18n.mavenDependency,
                code: `<dependency>
  <groupId>${PLACEHOLDER_GROUP_ID}</groupId>
  <artifactId>${PLACEHOLDER_ARTIFACT_ID}</artifactId>
  <version>${PLACEHOLDER_VERSION}</version>
</dependency>`,
                copyText: i18n.copyDependency,
              },
              {
                text: i18n.installCommand,
                code: 'mvn install',
                copyText: i18n.copyInstallCommand,
              },
            ]
          : [
              {
                text: i18n.mavenDistribution,
                code: `<distributionManagement>
  <repository>
    <id>${xmlName}</id>
    <url>${xmlUrl}</url>
  </repository>
</distributionManagement>`,
                copyText: i18n.copyDistribution,
              },
              {
                text: i18n.publishCommand,
                code: 'mvn deploy',
                copyText: i18n.copyPublishCommand,
              },
            ],
    },
    {
      heading: i18n.repositorySetup,
      blocks: [
        {
          text: i18n.mavenRepository,
          code: `<repositories>
  <repository>
    <id>${xmlName}</id>
    <url>${xmlUrl}</url>
  </repository>
</repositories>`,
          copyText: i18n.copyRepositoryConfig,
        },
        {
          text: i18n.mavenAuthentication,
          code: `<server>
  <id>${xmlName}</id>
  <configuration>
    <httpHeaders>
      <property>
        <name>Private-Token</name>
        <value>${TOKEN_PLACEHOLDER}</value>
      </property>
    </httpHeaders>
  </configuration>
</server>`,
          copyText: i18n.copyAuthConfig,
        },
      ],
    },
  ];
};

const npmSections = ({ tool, section, repositoryUrl }) => {
  const client = { [SETUP_TOOL_YARN]: 'yarn', [SETUP_TOOL_PNPM]: 'pnpm' }[tool] ?? 'npm';
  const addCommand = client === 'npm' ? 'install' : 'add';
  const publishCommand =
    client === 'yarn' ? YARN_BERRY_PUBLISH_VIA_NPM_PLUGIN : `${client} publish`;

  return [
    {
      blocks: [
        section === SETUP_SECTION_INSTALL
          ? {
              text: i18n.installCommand,
              code: `${client} ${addCommand} ${PLACEHOLDER_PACKAGE}`,
              copyText: i18n.copyInstallCommand,
            }
          : {
              text: i18n.publishCommand,
              code: publishCommand,
              copyText: i18n.copyPublishCommand,
            },
      ],
    },
    {
      heading: i18n.registrySetup,
      blocks: [
        tool === SETUP_TOOL_YARN
          ? {
              text: i18n.yarnrc,
              code: `npmScopes:
  ${PLACEHOLDER_SCOPE}:
    npmRegistryServer: "${repositoryUrl}"
    npmAuthToken: "${TOKEN_PLACEHOLDER}"`,
              copyText: i18n.copyRegistryConfig,
            }
          : {
              text: i18n.npmrc,
              code: `@${PLACEHOLDER_SCOPE}:registry=${repositoryUrl}
//${withoutScheme(repositoryUrl)}/:_authToken=${TOKEN_PLACEHOLDER}`,
              copyText: i18n.copyRegistryConfig,
            },
      ],
    },
  ];
};

const containerSections = ({ tool, section, repositoryUrl }) => {
  const client = tool === SETUP_TOOL_PODMAN ? 'podman' : 'docker';
  const reference = `${withoutScheme(repositoryUrl)}/${PLACEHOLDER_IMAGE}`;

  return [
    {
      blocks: [
        section === SETUP_SECTION_INSTALL
          ? {
              text: i18n.pullImage,
              code: `${client} pull ${reference}`,
              copyText: i18n.copyPullCommand,
            }
          : {
              text: i18n.pushImage,
              code: `${client} push ${reference}`,
              copyText: i18n.copyPushCommand,
            },
      ],
    },
    {
      heading: i18n.registrySetup,
      blocks: [
        {
          text: i18n.signIn,
          code: `echo "${TOKEN_PLACEHOLDER}" | ${client} login ${hostOf(repositoryUrl)} --username "${PLACEHOLDER_USERNAME}" --password-stdin`,
          copyText: i18n.copySignInCommand,
        },
      ],
    },
  ];
};

/* eslint-enable @gitlab/require-i18n-strings */

const SECTION_BUILDERS = {
  [REPOSITORY_FORMAT_DOCKER]: containerSections,
  [REPOSITORY_FORMAT_OCI]: containerSections,
  [REPOSITORY_FORMAT_MAVEN]: mavenSections,
  [REPOSITORY_FORMAT_NPM]: npmSections,
};

export const setupSnippetSections = ({ format, tool, section, name, repositoryUrl }) => {
  const build = SECTION_BUILDERS[format];

  if (!build || !repositoryUrl || !name) return [];

  return build({ tool, section, name, repositoryUrl });
};
