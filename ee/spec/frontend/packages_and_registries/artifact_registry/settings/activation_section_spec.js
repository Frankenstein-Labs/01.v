import { GlAlert, GlCard, GlSkeletonLoader } from '@gitlab/ui';
import Vue from 'vue';
import VueApollo from 'vue-apollo';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import ClipboardButton from '~/vue_shared/components/clipboard_button.vue';
import ActivationSection from 'ee/packages_and_registries/artifact_registry/settings/activation_section.vue';
import DisableConfirmation from 'ee/packages_and_registries/artifact_registry/settings/disable_confirmation.vue';
import getArtifactRegistryQuery from 'ee/packages_and_registries/artifact_registry/graphql/queries/get_artifact_registry.query.graphql';
import {
  CLIENT_BASE_URL,
  ORGANIZATION_GID,
  REGISTRY_HANDLE,
  mockArtifactRegistry,
  mockOrganizationHandler,
} from '../mock_data';

Vue.use(VueApollo);

describe('ArtifactRegistryActivationSection', () => {
  let wrapper;
  let organizationHandler;
  let registryResolver;
  let disableResolver;
  let enableResolver;
  let status;

  const DISABLE_PAYLOAD_TYPENAME = 'LocalArtifactRegistryDisablePayload';
  const ENABLE_PAYLOAD_TYPENAME = 'LocalArtifactRegistryEnablePayload';

  const findSkeleton = () => wrapper.findComponent(GlSkeletonLoader);
  const findAlert = () => wrapper.findComponent(GlAlert);
  const findCard = () => wrapper.findComponent(GlCard);
  const findClipboardButtons = () => wrapper.findAllComponents(ClipboardButton);
  const findIdentity = () => wrapper.findByTestId('registry-identity');
  const findHandle = () => wrapper.findByTestId('registry-handle');
  const findUrl = () => wrapper.findByTestId('registry-url');
  const findActiveSince = () => wrapper.findByTestId('registry-active-since');
  const findStatus = () => wrapper.findByTestId('registry-status');
  // The actions are found as components, so an example can read the state each reports as
  // well as the label it carries.
  const findDisableButton = () => wrapper.findComponentByTestId('disable-registry');
  const findEnableButton = () => wrapper.findComponentByTestId('enable-registry');
  const findConfirmation = () => wrapper.findComponent(DisableConfirmation);

  const createComponent = ({ clientBaseUrl = CLIENT_BASE_URL } = {}) => {
    organizationHandler = mockOrganizationHandler();

    wrapper = mountExtended(ActivationSection, {
      apolloProvider: createMockApollo([[getArtifactRegistryQuery, organizationHandler]], {
        Organization: { artifactRegistry: registryResolver },
        Mutation: {
          artifactRegistryDisable: disableResolver,
          artifactRegistryEnable: enableResolver,
        },
      }),
      provide: { organizationGid: ORGANIZATION_GID, clientBaseUrl },
    });
  };

  const createResolvedComponent = async (options) => {
    createComponent(options);
    await waitForPromises();
  };

  const resolveRegistry = (overrides) => {
    registryResolver = jest.fn(() => mockArtifactRegistry({ status, ...overrides }));
  };

  // The stand-in moves the status a later read reports as well as answering with it, so
  // the section may pick a transition up by re-reading or by patching its cache.
  const resolveCondition = (typename, nextStatus) =>
    jest.fn(() => {
      status = nextStatus;

      return {
        __typename: typename,
        registry: mockArtifactRegistry({ status: nextStatus }),
        errors: [],
      };
    });

  const refuseCondition = (typename, errors) =>
    jest.fn().mockResolvedValue({ __typename: typename, registry: null, errors });

  // The dialog closes itself as it confirms: GlModal hides on its primary action and the
  // confirmation forwards that, so the action runs with no dialog left on screen.
  const confirmDisable = async () => {
    findConfirmation().vm.$emit('confirm');
    findConfirmation().vm.$emit('change', false);
    await waitForPromises();
  };

  const disable = async () => {
    await findDisableButton().trigger('click');
    await confirmDisable();
  };

  const enable = async () => {
    await findEnableButton().trigger('click');
    await waitForPromises();
  };

  beforeEach(() => {
    status = 'active';
    resolveRegistry();
    disableResolver = resolveCondition(DISABLE_PAYLOAD_TYPENAME, 'disabled');
    enableResolver = resolveCondition(ENABLE_PAYLOAD_TYPENAME, 'active');
  });

  describe('while the registry is being read', () => {
    beforeEach(() => {
      createComponent();
    });

    it('stands a loading affordance in for the identity, reporting no state it has not read', () => {
      expect(findSkeleton().exists()).toBe(true);
      expect(findIdentity().exists()).toBe(false);
      expect(findStatus().exists()).toBe(false);
      expect(findCard().exists()).toBe(false);
      expect(findAlert().exists()).toBe(false);
    });
  });

  describe('when the registry resolves', () => {
    beforeEach(() => createResolvedComponent());

    it('reads the registry of the organization it was mounted for', () => {
      expect(organizationHandler).toHaveBeenCalledTimes(1);
      expect(organizationHandler).toHaveBeenCalledWith({ organizationId: ORGANIZATION_GID });
    });

    it('names the handle, the client URL composed from it, and the date it was activated', () => {
      expect(findHandle().text()).toBe(REGISTRY_HANDLE);
      expect(findUrl().text()).toBe(`${CLIENT_BASE_URL}/${REGISTRY_HANDLE}`);
      expect(findActiveSince().text()).toBe('Aug 6, 2026');
    });

    it('labels each identity value, so none of the three is an unexplained string', () => {
      expect(findIdentity().text()).toContain('Registry handle');
      expect(findIdentity().text()).toContain('Registry URL');
      expect(findIdentity().text()).toContain('Active since');
    });

    it('renders the identity rather than the loading affordance or an error', () => {
      expect(findIdentity().exists()).toBe(true);
      expect(findCard().exists()).toBe(true);
      expect(findSkeleton().exists()).toBe(false);
      expect(findAlert().exists()).toBe(false);
    });

    it('offers the handle and the registry URL for copying, and the date not at all', () => {
      expect(findClipboardButtons().wrappers.map((button) => button.props('text'))).toEqual([
        REGISTRY_HANDLE,
        `${CLIENT_BASE_URL}/${REGISTRY_HANDLE}`,
      ]);
    });

    it('says which value each copy action takes, so neither is an unlabelled icon', () => {
      expect(findClipboardButtons().wrappers.map((button) => button.props('title'))).toEqual([
        'Copy registry handle',
        'Copy registry URL',
      ]);
    });
  });

  describe('when the instance configures no Artifact Registry origin', () => {
    beforeEach(() => createResolvedComponent({ clientBaseUrl: null }));

    it('still names the handle, and no registry URL rather than one with a hole in it', () => {
      expect(findHandle().text()).toBe(REGISTRY_HANDLE);
      expect(findUrl().exists()).toBe(false);
    });

    it('offers the handle for copying and no copy action for the URL it does not render', () => {
      expect(findClipboardButtons().wrappers.map((button) => button.props('text'))).toEqual([
        REGISTRY_HANDLE,
      ]);
    });
  });

  describe('the status indication', () => {
    it.each([
      ['active', 'Artifact Registry is enabled'],
      ['disabled', 'Artifact Registry is disabled'],
      ['suspended', 'Artifact Registry is not available for this organization'],
      ['blocked', 'Artifact Registry is not available for this organization'],
      ['deleted', 'Artifact Registry is not available for this organization'],
      ['purged', 'Artifact Registry is not available for this organization'],
    ])('indicates %p as %p', async (registryStatus, indication) => {
      resolveRegistry({ status: registryStatus });

      await createResolvedComponent();

      expect(findStatus().text()).toBe(indication);
    });

    it('indicates a status it does not recognize neutrally, beside the identity', async () => {
      resolveRegistry({ status: 'unrecognized-status' });

      await createResolvedComponent();

      expect(findStatus().text()).toBe('Artifact Registry is not available for this organization');
      expect(findHandle().text()).toBe(REGISTRY_HANDLE);
      expect(findAlert().exists()).toBe(false);
    });
  });

  describe('the action the status permits', () => {
    // See `REGISTRY_STATUS_ACTIONS` in constants.js for why a status may carry no action.
    it.each`
      registryStatus           | offersDisable | offersEnable
      ${'active'}              | ${true}       | ${false}
      ${'disabled'}            | ${false}      | ${true}
      ${'suspended'}           | ${false}      | ${false}
      ${'blocked'}             | ${false}      | ${false}
      ${'deleted'}             | ${false}      | ${false}
      ${'purged'}              | ${false}      | ${false}
      ${'unrecognized-status'} | ${false}      | ${false}
    `(
      'offers disable=$offersDisable and enable=$offersEnable for $registryStatus',
      async ({ registryStatus, offersDisable, offersEnable }) => {
        resolveRegistry({ status: registryStatus });

        await createResolvedComponent();

        expect(findDisableButton().exists()).toBe(offersDisable);
        expect(findEnableButton().exists()).toBe(offersEnable);
      },
    );

    it('names the disable after the transition it makes, and after what it acts on', async () => {
      await createResolvedComponent();

      expect(findDisableButton().text()).toBe('Disable Artifact Registry');
    });

    // The two are one control in two states, so the enable names its object as the
    // disable does rather than standing alone as a bare verb.
    it('names the enable the same way, so the pair does not read as two unrelated controls', async () => {
      resolveRegistry({ status: 'disabled' });

      await createResolvedComponent();

      expect(findEnableButton().text()).toBe('Enable Artifact Registry');
    });
  });

  describe('disabling the registry', () => {
    beforeEach(() => createResolvedComponent());

    it('names the handle the confirmation requires, and opens it only when asked', async () => {
      expect(findConfirmation().props()).toMatchObject({
        handle: REGISTRY_HANDLE,
        visible: false,
      });

      await findDisableButton().trigger('click');

      expect(findConfirmation().props('visible')).toBe(true);
    });

    it('disables nothing until the confirmation is confirmed, so a stray click cannot', async () => {
      await findDisableButton().trigger('click');
      await waitForPromises();

      expect(disableResolver).not.toHaveBeenCalled();
      expect(findStatus().text()).toBe('Artifact Registry is enabled');
    });

    describe('once confirmed', () => {
      beforeEach(() => disable());

      it('disables the registry of the organization it was mounted for', () => {
        expect(disableResolver).toHaveBeenCalledTimes(1);
        expect(disableResolver).toHaveBeenCalledWith(
          expect.anything(),
          { input: { organizationId: ORGANIZATION_GID } },
          expect.anything(),
          expect.anything(),
        );
      });

      it('reports the registry as disabled and offers to enable it, not to disable it again', () => {
        expect(findStatus().text()).toBe('Artifact Registry is disabled');
        expect(findEnableButton().exists()).toBe(true);
        expect(findDisableButton().exists()).toBe(false);
      });

      it('keeps the identity, which the transition does not change', () => {
        expect(findHandle().text()).toBe(REGISTRY_HANDLE);
        expect(findActiveSince().text()).toBe('Aug 6, 2026');
      });

      it('hands the outcome up to be announced', () => {
        expect(wrapper.emitted('success')).toEqual([['Artifact Registry was disabled.']]);
        expect(wrapper.emitted('error')).toBeUndefined();
      });
    });

    describe('while the disable is in flight', () => {
      beforeEach(async () => {
        disableResolver = jest.fn(() => new Promise(() => {}));

        await createResolvedComponent();
        await findDisableButton().trigger('click');
        await confirmDisable();
      });

      it('reports the run on the disable, which the confirmation has closed over', () => {
        expect(findDisableButton().props('loading')).toBe(true);
      });

      it('cannot be pressed again, so the confirmation does not reopen over a running disable', async () => {
        await findDisableButton().trigger('click');

        expect(findConfirmation().props('visible')).toBe(false);
        expect(disableResolver).toHaveBeenCalledTimes(1);
      });
    });

    // The mutation reported no error and Artifact Registry applied the condition, so the
    // action succeeded whatever the read that follows it does.
    describe('when the state cannot be read back after the disable', () => {
      beforeEach(async () => {
        registryResolver = jest
          .fn()
          .mockResolvedValueOnce(mockArtifactRegistry({ status: 'active' }))
          .mockRejectedValue(new Error('Artifact Registry is down'));

        await createResolvedComponent();
        await disable();
      });

      it('announces the action that succeeded, and no failure', () => {
        expect(wrapper.emitted('success')).toEqual([['Artifact Registry was disabled.']]);
        expect(wrapper.emitted('error')).toBeUndefined();
      });

      it('reports the state it could not read as unavailable, rather than as the state before', () => {
        expect(findAlert().text()).toBe('The Artifact Registry service is unavailable.');
        expect(findIdentity().exists()).toBe(false);
      });
    });

    describe('when Artifact Registry refuses the disable', () => {
      beforeEach(async () => {
        disableResolver = refuseCondition(DISABLE_PAYLOAD_TYPENAME, [
          'Namespace not found.',
          'Try again later.',
        ]);

        await createResolvedComponent();
        await disable();
      });

      it('announces every refusal it was given, rather than reporting a disable', () => {
        expect(wrapper.emitted('error')).toEqual([['Namespace not found. Try again later.']]);
        expect(wrapper.emitted('success')).toBeUndefined();
      });

      it('leaves the registry reported as enabled, with the disable still on offer', () => {
        expect(findStatus().text()).toBe('Artifact Registry is enabled');
        expect(findDisableButton().exists()).toBe(true);
        expect(findEnableButton().exists()).toBe(false);
      });
    });

    describe('when the disable fails outright', () => {
      beforeEach(async () => {
        disableResolver = jest.fn().mockRejectedValue(new Error('Artifact Registry is down'));

        await createResolvedComponent();
        await disable();
      });

      it('announces the failure rather than appearing to succeed', () => {
        expect(wrapper.emitted('error')).toEqual([['Something went wrong. Please try again.']]);
        expect(wrapper.emitted('success')).toBeUndefined();
      });

      it('leaves the registry reported as enabled, with the disable still on offer', () => {
        expect(findStatus().text()).toBe('Artifact Registry is enabled');
        expect(findDisableButton().exists()).toBe(true);
      });
    });
  });

  describe('enabling the registry', () => {
    beforeEach(() => {
      status = 'disabled';
      resolveRegistry();
    });

    describe('when the enable succeeds', () => {
      beforeEach(async () => {
        await createResolvedComponent();
        await enable();
      });

      it('enables the registry of the organization it was mounted for, with no phrase to type', () => {
        expect(enableResolver).toHaveBeenCalledTimes(1);
        expect(enableResolver).toHaveBeenCalledWith(
          expect.anything(),
          { input: { organizationId: ORGANIZATION_GID } },
          expect.anything(),
          expect.anything(),
        );
      });

      it('returns the section to the enabled state and offers to disable it', () => {
        expect(findStatus().text()).toBe('Artifact Registry is enabled');
        expect(findDisableButton().exists()).toBe(true);
        expect(findEnableButton().exists()).toBe(false);
      });

      it('hands the outcome up to be announced', () => {
        expect(wrapper.emitted('success')).toEqual([['Artifact Registry was enabled.']]);
        expect(wrapper.emitted('error')).toBeUndefined();
      });
    });

    describe('when Artifact Registry refuses the enable', () => {
      beforeEach(async () => {
        enableResolver = refuseCondition(ENABLE_PAYLOAD_TYPENAME, ['Namespace not found.']);

        await createResolvedComponent();
        await enable();
      });

      it('announces the refusal rather than reporting an enable', () => {
        expect(wrapper.emitted('error')).toEqual([['Namespace not found.']]);
        expect(wrapper.emitted('success')).toBeUndefined();
      });

      it('leaves the registry reported as disabled, with the enable still on offer', () => {
        expect(findStatus().text()).toBe('Artifact Registry is disabled');
        expect(findEnableButton().exists()).toBe(true);
      });
    });

    describe('when the enable fails outright', () => {
      beforeEach(async () => {
        enableResolver = jest.fn().mockRejectedValue(new Error('Artifact Registry is down'));

        await createResolvedComponent();
        await enable();
      });

      it('announces the failure rather than appearing to succeed', () => {
        expect(wrapper.emitted('error')).toEqual([['Something went wrong. Please try again.']]);
        expect(wrapper.emitted('success')).toBeUndefined();
      });

      it('leaves the registry reported as disabled, with the enable still on offer', () => {
        expect(findStatus().text()).toBe('Artifact Registry is disabled');
        expect(findEnableButton().exists()).toBe(true);
      });
    });
  });

  // A completed action is not offered again, but the inverse one is, and the dialog
  // belonging to the action that ran must not return with it.
  describe('disabling and then enabling the registry', () => {
    beforeEach(async () => {
      await createResolvedComponent();
      await disable();
      await enable();
    });

    it('offers the disable again with its confirmation closed, rather than reopened unprompted', () => {
      expect(findDisableButton().exists()).toBe(true);
      expect(findConfirmation().props('visible')).toBe(false);
    });
  });

  describe.each([
    ['the read fails', () => jest.fn().mockRejectedValue(new Error('Artifact Registry is down'))],
    ['the field resolves null', () => jest.fn().mockResolvedValue(null)],
  ])('when %s', (_, buildResolver) => {
    beforeEach(async () => {
      registryResolver = buildResolver();

      await createResolvedComponent();
    });

    it('replaces the identity with the service-unavailable error, naming no status', () => {
      expect(findAlert().text()).toBe('The Artifact Registry service is unavailable.');
      expect(findIdentity().exists()).toBe(false);
      expect(findCard().exists()).toBe(false);
      expect(findStatus().exists()).toBe(false);
      expect(findClipboardButtons()).toHaveLength(0);
    });

    it('leaves the error in place rather than offering to dismiss a state that persists', () => {
      expect(findAlert().props('dismissible')).toBe(false);
    });

    it('offers neither action, since no action has a precondition the section knows', () => {
      expect(findDisableButton().exists()).toBe(false);
      expect(findEnableButton().exists()).toBe(false);
    });
  });
});
