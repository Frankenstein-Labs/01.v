import { GlCollapse } from '@gitlab/ui';
import Vue from 'vue';
import VueApollo from 'vue-apollo';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import SetupForm from 'ee/packages_and_registries/artifact_registry/setup/setup_form.vue';
import { CLIENT_BASE_URL, ORGANIZATION_GID } from '../mock_data';

Vue.use(VueApollo);

describe('ArtifactRegistrySetupForm', () => {
  let wrapper;
  let activateResolver;

  const HANDLE = 'my-registry';
  const ORGANIZATION_PATH = 'gitlab-org';

  // Equal to HANDLE, and separate from it on purpose: the cases that turn on the
  // difference between a typed handle and the stood-in one type something else.
  const HANDLE_PLACEHOLDER = 'my-registry';

  const REGISTRY_URL = `${CLIENT_BASE_URL}/${HANDLE}`;
  const REGISTRY_HOST = REGISTRY_URL.replace('https://', '');

  const PLACEHOLDER_REGISTRY_URL = `${CLIENT_BASE_URL}/${HANDLE_PLACEHOLDER}`;
  const PLACEHOLDER_REGISTRY_HOST = PLACEHOLDER_REGISTRY_URL.replace('https://', '');

  const MOCK_REGISTRY = {
    __typename: 'ArtifactRegistry',
    handle: HANDLE,
    status: 'active',
    createdAt: '2026-08-06T00:00:00Z',
  };

  const MOCK_SUCCESS_PAYLOAD = {
    __typename: 'LocalArtifactRegistryActivatePayload',
    registry: MOCK_REGISTRY,
    errors: [],
  };

  const mockRefusalPayload = (errors) => ({
    __typename: 'LocalArtifactRegistryActivatePayload',
    registry: null,
    errors,
  });

  const findHandleInput = () => wrapper.findByTestId('registry-handle');
  const findHandleGroup = () => wrapper.findComponentByTestId('registry-handle-group');
  const findHandleRefusal = () => findHandleGroup().find('.invalid-feedback');
  const findHandleDescription = () => wrapper.findByTestId('label-description');
  const findHandleHint = () => wrapper.findByTestId('registry-handle-hint');
  const findUrlPrefix = () => wrapper.findByTestId('handle-url-prefix');
  const findUrlSuffix = () => wrapper.findByTestId('handle-url-suffix');
  const findPermanenceCallout = () => wrapper.findComponentByTestId('permanence-callout');
  const findUsageToggle = () => wrapper.findByTestId('handle-usage-toggle');
  const findUsagePanel = () => wrapper.findComponent(GlCollapse);
  const findUsageExample = (name) => wrapper.findByTestId(`handle-usage-${name}`);
  const findSubmitButton = () => wrapper.findComponentByTestId('submit-activation');

  const collapseWhitespace = (text) => text.replace(/\s+/g, ' ').trim();

  const createComponent = ({ clientBaseUrl = CLIENT_BASE_URL } = {}) => {
    activateResolver = jest.fn().mockResolvedValue(MOCK_SUCCESS_PAYLOAD);

    wrapper = mountExtended(SetupForm, {
      apolloProvider: createMockApollo([], {
        Mutation: { artifactRegistryActivate: activateResolver },
      }),
      provide: {
        organizationGid: ORGANIZATION_GID,
        organizationPath: ORGANIZATION_PATH,
        clientBaseUrl,
      },
      attachTo: document.body,
    });
  };

  const updateHandle = async (handle) => {
    await findHandleInput().setValue(handle);
    await waitForPromises();
  };

  const submitForm = async () => {
    await wrapper.find('form').trigger('submit');
    await waitForPromises();
  };

  const claim = async (handle = HANDLE) => {
    await updateHandle(handle);
    await submitForm();
  };

  beforeEach(() => {
    createComponent();
  });

  describe('the handle field', () => {
    it('says what the handle is, rather than restating its syntax', () => {
      expect(findHandleDescription().text()).toBe(
        'A permanent, unique identifier used across every Artifact Registry URL and client config file.',
      );
    });

    it('states the syntax as a hint under the field', () => {
      expect(findHandleHint().text()).toBe(
        'Only lowercase letters, digits and hyphens (-) are allowed. Must start and end with an alphanumeric character.',
      );
    });

    it('stands a handle in for the empty field', () => {
      expect(findHandleInput().attributes('placeholder')).toBe(HANDLE_PLACEHOLDER);
    });
  });

  describe('the registry URL frame', () => {
    it('frames the field with the registry origin and the path the handle opens', () => {
      expect(findUrlPrefix().text()).toBe(`${CLIENT_BASE_URL}/`);
      expect(findUrlSuffix().text()).toBe('/...');
    });

    it('supersedes the standalone URL preview', async () => {
      await updateHandle(HANDLE);

      expect(wrapper.findByTestId('registry-url-preview').exists()).toBe(false);
    });

    describe('when the instance configures no Artifact Registry origin', () => {
      beforeEach(() => {
        createComponent({ clientBaseUrl: null });
      });

      it('frames nothing rather than framing the field with half a URL', () => {
        expect(findUrlPrefix().exists()).toBe(false);
        expect(findUrlSuffix().exists()).toBe(false);
      });
    });
  });

  describe('the where-it-appears disclosure', () => {
    it('is a button a keyboard reaches, reporting its collapsed state', () => {
      expect(findUsageToggle().element.tagName).toBe('BUTTON');
      expect(findUsageToggle().attributes('aria-expanded')).toBe('false');
      expect(findUsagePanel().props('visible')).toBe(false);
    });

    it('expands the panel when the toggle is operated', async () => {
      await findUsageToggle().trigger('click');

      expect(findUsageToggle().attributes('aria-expanded')).toBe('true');
      expect(findUsagePanel().props('visible')).toBe(true);
    });

    it('names the areas the handle reaches', () => {
      expect(findUsagePanel().text()).toContain(
        'The registry handle will appear in the following areas:',
      );
    });

    it.each([
      'GitLab UI',
      'URL:',
      'Client configuration files',
      'npm (.npmrc):',
      'Maven (settings.xml):',
      'CI/CD pipelines (.gitlab-ci.yml)',
      'Dockerfiles',
      'Team documentation / READMEs:',
    ])('names the %p area', (label) => {
      expect(findUsagePanel().text()).toContain(label);
    });

    describe('with a handle typed', () => {
      beforeEach(() => updateHandle(HANDLE));

      it.each([
        ['ui-url', `/o/${ORGANIZATION_PATH}/-/artifact_registry/${HANDLE}/repositories`],
        ['npm', `@scope:registry=${REGISTRY_URL}/npm/my-repo`],
        ['maven', `<url>${REGISTRY_URL}/maven/my-repo</url>`],
        ['ci', `publish: script: - docker push ${REGISTRY_HOST}/container/my-repo/my-image:latest`],
        ['dockerfile', `FROM ${REGISTRY_HOST}/container/my-repo/my-image:latest`],
        ['docs', `Our internal packages are hosted at ${REGISTRY_HOST}/npm/shared-libs`],
      ])('shows the %s example the handle produces', (name, example) => {
        expect(collapseWhitespace(findUsageExample(name).text())).toBe(example);
      });

      it('follows the handle as it is edited, so each candidate can be judged in place', async () => {
        await updateHandle('other-handle');

        expect(findUsageExample('ui-url').text()).toBe(
          `/o/${ORGANIZATION_PATH}/-/artifact_registry/other-handle/repositories`,
        );
        expect(findUsageExample('npm').text()).toBe(
          `@scope:registry=${CLIENT_BASE_URL}/other-handle/npm/my-repo`,
        );
      });
    });

    describe('with the field empty', () => {
      it.each([
        [
          'ui-url',
          `/o/${ORGANIZATION_PATH}/-/artifact_registry/${HANDLE_PLACEHOLDER}/repositories`,
        ],
        ['npm', `@scope:registry=${PLACEHOLDER_REGISTRY_URL}/npm/my-repo`],
        ['maven', `<url>${PLACEHOLDER_REGISTRY_URL}/maven/my-repo</url>`],
        [
          'ci',
          `publish: script: - docker push ${PLACEHOLDER_REGISTRY_HOST}/container/my-repo/my-image:latest`,
        ],
        ['dockerfile', `FROM ${PLACEHOLDER_REGISTRY_HOST}/container/my-repo/my-image:latest`],
        [
          'docs',
          `Our internal packages are hosted at ${PLACEHOLDER_REGISTRY_HOST}/npm/shared-libs`,
        ],
      ])('composes the %s example from the placeholder', (name, example) => {
        expect(collapseWhitespace(findUsageExample(name).text())).toBe(example);
      });
    });

    describe('when a typed handle is cleared', () => {
      it.each([
        [
          'ui-url',
          `/o/${ORGANIZATION_PATH}/-/artifact_registry/other-handle/repositories`,
          `/o/${ORGANIZATION_PATH}/-/artifact_registry/${HANDLE_PLACEHOLDER}/repositories`,
        ],
        [
          'npm',
          `@scope:registry=${CLIENT_BASE_URL}/other-handle/npm/my-repo`,
          `@scope:registry=${PLACEHOLDER_REGISTRY_URL}/npm/my-repo`,
        ],
      ])('returns the %s example to the placeholder', async (name, typed, placeholder) => {
        await updateHandle('other-handle');

        expect(findUsageExample(name).text()).toBe(typed);

        await updateHandle('');

        expect(findUsageExample(name).text()).toBe(placeholder);
      });
    });

    describe('when the instance configures no Artifact Registry origin', () => {
      beforeEach(async () => {
        createComponent({ clientBaseUrl: null });
        await updateHandle(HANDLE);
      });

      it.each(['npm', 'maven', 'ci', 'dockerfile', 'docs'])(
        'shows no %s example rather than one with a hole in it',
        (name) => {
          expect(findUsageExample(name).exists()).toBe(false);
        },
      );

      it('still shows the GitLab UI URL, which the origin does not compose', () => {
        expect(findUsageExample('ui-url').text()).toBe(
          `/o/${ORGANIZATION_PATH}/-/artifact_registry/${HANDLE}/repositories`,
        );
      });
    });
  });

  describe('the permanence acknowledgment', () => {
    it('says the handle is permanent and cannot be reclaimed', () => {
      expect(findPermanenceCallout().props('title')).toBe(
        'Registry handle is permanent and globally reserved',
      );
      expect(findPermanenceCallout().text()).toContain(
        'This cannot be changed once claimed, even if Artifact Registry is disabled later. Choose something that represents your organization long-term.',
      );
    });
  });

  describe('the claim control', () => {
    it('names the outcome of the claim', () => {
      expect(findSubmitButton().text()).toBe('Enable Artifact registry');
    });
  });

  describe('inline validation', () => {
    it.each([
      ['it is empty', '', 'Registry handle is required.'],
      [
        'it carries an uppercase letter',
        'My-Registry',
        'Only lowercase letters, digits and hyphens (-) are allowed. Remove any spaces or special characters.',
      ],
      [
        'it carries a disallowed character',
        'my_registry',
        'Only lowercase letters, digits and hyphens (-) are allowed. Remove any spaces or special characters.',
      ],
      [
        'it leads with a hyphen',
        '-my-registry',
        'Must start and end with an alphanumeric character.',
      ],
      [
        'it trails with a hyphen',
        'my-registry-',
        'Must start and end with an alphanumeric character.',
      ],
      ['it is too short', 'ab', 'Must be between 3 and 63 characters.'],
      ['it is too long', 'a'.repeat(64), 'Must be between 3 and 63 characters.'],
      ['it repeats a hyphen', 'my--registry', 'Must not contain consecutive hyphens (--).'],
    ])('refuses the handle when %s, without claiming it', async (_, handle, message) => {
      await claim(handle);

      expect(findHandleRefusal().text()).toBe(message);
      expect(activateResolver).not.toHaveBeenCalled();
    });

    it('associates the refusal with the field, so it is announced with it', async () => {
      await claim('my_registry');

      expect(findHandleInput().attributes('aria-describedby')).toContain(
        findHandleRefusal().attributes('id'),
      );
    });

    it.each(['abc', 'my-registry', 'a1-b2-c3', '0-9', 'a'.repeat(63)])(
      'accepts %p',
      async (handle) => {
        await claim(handle);

        expect(activateResolver).toHaveBeenCalledTimes(1);
      },
    );
  });

  describe('when a valid handle is claimed', () => {
    beforeEach(() => claim());

    it('sends the organization and the handle, and nothing else', () => {
      expect(activateResolver).toHaveBeenCalledWith(
        {},
        { input: { organizationId: ORGANIZATION_GID, handle: HANDLE } },
        expect.anything(),
        expect.anything(),
      );
    });

    it('hands the claimed registry to the page', () => {
      expect(wrapper.emitted('success')).toEqual([[MOCK_REGISTRY]]);
    });

    it('stays busy, so the claim cannot be repeated behind the redirect', () => {
      expect(findSubmitButton().props('loading')).toBe(true);
    });
  });

  // The claimed handle is written out rather than taken from HANDLE, which carries the
  // placeholder's own value. Folding it into HANDLE would leave this case, and the two
  // cleared-field cases beside it, equally satisfied by a form that submitted the
  // stand-in, which is the one thing the three of them exist to rule out.
  describe('when the typed handle differs from the placeholder', () => {
    it('claims what was typed, not the placeholder standing in for it', async () => {
      await claim('other-handle');

      expect(activateResolver).toHaveBeenCalledWith(
        {},
        { input: { organizationId: ORGANIZATION_GID, handle: 'other-handle' } },
        expect.anything(),
        expect.anything(),
      );
    });
  });

  describe('while the claim is in flight', () => {
    let resolveActivate;

    beforeEach(async () => {
      activateResolver.mockImplementation(
        () =>
          new Promise((resolve) => {
            resolveActivate = resolve;
          }),
      );

      await claim();
    });

    afterEach(async () => {
      resolveActivate(MOCK_SUCCESS_PAYLOAD);
      await waitForPromises();
    });

    it('reports the form as busy', () => {
      expect(findSubmitButton().props('loading')).toBe(true);
    });

    it('issues no second claim when submitted again', async () => {
      await submitForm();

      expect(activateResolver).toHaveBeenCalledTimes(1);
    });
  });

  describe('when Artifact Registry refuses the handle', () => {
    beforeEach(async () => {
      activateResolver.mockResolvedValue(mockRefusalPayload(['Handle has already been taken.']));

      await claim();
    });

    it('renders the refusal against the handle field', () => {
      expect(findHandleRefusal().text()).toBe('Handle has already been taken.');
    });

    it('hands nothing to the page', () => {
      expect(wrapper.emitted('success')).toBeUndefined();
    });

    it('leaves the form editable, so another handle can be claimed', async () => {
      activateResolver.mockResolvedValue(MOCK_SUCCESS_PAYLOAD);

      await claim('another-registry');

      expect(activateResolver).toHaveBeenLastCalledWith(
        {},
        { input: { organizationId: ORGANIZATION_GID, handle: 'another-registry' } },
        expect.anything(),
        expect.anything(),
      );
    });
  });
});
