import { SETUP_SECTION_INSTALL, SETUP_SECTION_PUBLISH, SETUP_TOOLS } from '../../../constants';
import SetupSnippets from './setup_snippets.vue';
import ToolSelector from './tool_selector.vue';

export default {
  component: SetupSnippets,
  title: 'ee/artifact_registry/repositories/detail/setup_instructions/setup_snippets',
};

const Template = (format, section) => () => ({
  components: { SetupSnippets, ToolSelector },
  provide: {
    slug: 'acme',
    clientBaseUrl: 'https://ar.gitlab.com',
  },
  data() {
    return { format, section, tool: SETUP_TOOLS[format][0].value };
  },
  template: `
    <div class="gl-max-w-80">
      <tool-selector :format="format" :selected="tool" @select="tool = $event" />
      <setup-snippets class="gl-mt-4" name="my-repository" :format="format" :tool="tool" :section="section" />
    </div>
  `,
});

export const MavenInstall = Template('MAVEN', SETUP_SECTION_INSTALL);

export const MavenPublish = Template('MAVEN', SETUP_SECTION_PUBLISH);

export const NpmInstall = Template('NPM', SETUP_SECTION_INSTALL);

export const NpmPublish = Template('NPM', SETUP_SECTION_PUBLISH);

export const DockerInstall = Template('DOCKER', SETUP_SECTION_INSTALL);

export const DockerPublish = Template('DOCKER', SETUP_SECTION_PUBLISH);

export const OciInstall = Template('OCI', SETUP_SECTION_INSTALL);

export const OciPublish = Template('OCI', SETUP_SECTION_PUBLISH);
