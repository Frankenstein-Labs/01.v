import { GlLink, GlSprintf } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import ClipboardButton from '~/vue_shared/components/clipboard_button.vue';
import CodeBlockHighlighted from '~/vue_shared/components/code_block_highlighted.vue';

import SetupScript from 'ee/integrations/edit/components/google_cloud_iam/setup_script.vue';

describe('SetupScript', () => {
  const wlifIssuer = 'https://test.com';
  const googleProjectId = 'example-project-id';
  const identityPoolId = 'examplePoolId';
  const identityProviderId = 'exampleProviderId';
  const jwtClaims = 'examplegcpattr=exampleglattr';
  const suggestedDisplayName = 'GitLab project ID 42';

  let wrapper;
  const createComponent = () => {
    wrapper = shallowMount(SetupScript, {
      propsData: {
        wlifIssuer,
        googleProjectId,
        identityPoolId,
        identityProviderId,
        jwtClaims,
        suggestedDisplayName,
      },
      stubs: { GlSprintf },
    });
  };

  const findLinks = () => wrapper.findAllComponents(GlLink);
  const findCodeBlock = () => wrapper.findComponent(CodeBlockHighlighted);
  const findClipboardButton = () => wrapper.findComponent(ClipboardButton);

  const expectCmdToContainRelevantProps = (cmd) => {
    expect(cmd).toContain(`create "${identityPoolId}"`);
    expect(cmd).toContain(`--project="${googleProjectId}"`);
    expect(cmd).toContain(`--display-name="${suggestedDisplayName}"`);
    expect(cmd).toContain(`create-oidc "${identityProviderId}"`);
    expect(cmd).toContain(`--workload-identity-pool="${identityPoolId}"`);
    expect(cmd).toContain(`--issuer-uri="${wlifIssuer}"`);
    expect(cmd).toContain(`--attribute-mapping="${jwtClaims}"`);
  };

  beforeEach(() => {
    createComponent();
  });

  it('renders gcloud setup commands', () => {
    const codeBlock = findCodeBlock();
    const cmd = codeBlock.props('code');

    expectCmdToContainRelevantProps(cmd);
  });

  it('links to gcloud setup instructions', () => {
    const setupLink = findLinks().at(1);

    expect(setupLink.attributes('href')).toBe(
      'https://cloud.google.com/sdk/docs/install#installation_instructions',
    );
  });

  it('includes a clipboard button to copy the commands', () => {
    const btn = findClipboardButton();
    const cmd = btn.props('text');

    expectCmdToContainRelevantProps(cmd);
  });
});
