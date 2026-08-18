import Vue, { nextTick } from 'vue';
import VueRouter from 'vue-router';
import VueApollo from 'vue-apollo';
import { GlButton, GlIcon, GlAlert } from '@gitlab/ui';
import { useMockInternalEventsTracking } from 'helpers/tracking_internal_events_helper';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import EnableScannersWizard from 'ee/security_configuration/components/enable_scanners_wizard/app.vue';
import ConfirmUnsavedChangesDialog from '~/vue_shared/components/confirm_unsaved_changes_dialog.vue';
import {
  ROUTE_APPROACH,
  ROUTE_ITEMS,
  ROUTE_SCANNERS,
  ROUTE_REVIEW,
  ROUTE_CONFIRMATION,
  APPROACH_QUICK,
  APPROACH_ADVANCED,
} from 'ee/security_configuration/components/enable_scanners_wizard/constants';
import { routes } from 'ee/security_configuration/routes';
import groupAvailableSecurityScanProfilesQuery from 'ee/security_configuration/graphql/scan_profiles/group_available_security_scan_profiles.query.graphql';
import securityScanProfileAttachMutation from 'ee/security_configuration/graphql/scan_profiles/security_scan_profile_attach.mutation.graphql';
import { mockScanner, mockScanner2 } from '../scan_profiles/mock_data';

Vue.use(VueRouter);
Vue.use(VueApollo);

const GROUP_FULL_PATH = 'group/path';
const GROUP_ID = 1;
const GROUP_GID = 'gid://gitlab/Group/1';

const sastProfile = mockScanner2;
const secretProfile1 = mockScanner;
const secretProfile2 = {
  id: 'gid://gitlab/Security::ScanProfile/3',
  name: 'Alternate Secret Detection Profile',
  description: 'Detects secrets too',
  scanType: 'SECRET_DETECTION',
  gitlabRecommended: false,
  triggers: ['GIT_PUSH_EVENT'],
  __typename: 'ScanProfileType',
};
const availableScanners = [sastProfile, secretProfile1, secretProfile2];

const defaultAvailableScannersHandler = () =>
  jest.fn().mockResolvedValue({
    data: {
      group: {
        id: GROUP_GID,
        name: 'group',
        availableSecurityScanProfiles: availableScanners,
        __typename: 'Group',
      },
    },
  });

const attachHandlerWithErrors = (errors = []) =>
  jest.fn().mockResolvedValue({
    data: {
      securityScanProfileAttach: {
        __typename: 'SecurityScanProfileAttachPayload',
        clientMutationId: '1',
        errors,
      },
    },
  });

describe('EnableScannersWizard', () => {
  let wrapper;
  let router;
  let availableScannersHandler;
  let attachHandler;

  const { bindInternalEventDocument } = useMockInternalEventsTracking();

  const createComponent = async ({
    approach = APPROACH_QUICK,
    initialRoute = ROUTE_APPROACH,
    initialRouteQuery = {},
    selectedItems = [],
    selectedScanners = [],
    areAllItemsSelected = false,
    availableScannersHandler: availableScannersHandlerOverride,
    attachHandler: attachHandlerOverride,
  } = {}) => {
    availableScannersHandler =
      availableScannersHandlerOverride ?? defaultAvailableScannersHandler();
    attachHandler = attachHandlerOverride ?? attachHandlerWithErrors();

    wrapper?.destroy();
    router = new VueRouter({ routes });
    await router.push({ name: initialRoute, query: initialRouteQuery });

    wrapper = shallowMountExtended(EnableScannersWizard, {
      router,
      apolloProvider: createMockApollo([
        [groupAvailableSecurityScanProfilesQuery, availableScannersHandler],
        [securityScanProfileAttachMutation, attachHandler],
      ]),
      provide: { groupFullPath: GROUP_FULL_PATH, groupId: GROUP_ID },
      data: () => ({ approach, selectedItems, selectedScanners, areAllItemsSelected }),
    });
  };

  const findSteps = () => wrapper.findAllByTestId('wizard-step');
  const findStepCheckmarks = () =>
    wrapper
      .findAllComponents(GlIcon)
      .wrappers.filter((icon) => icon.props('name') === 'check-circle-filled');
  const findRouterView = () => wrapper.findComponent({ name: 'RouterView' });
  const findButtons = () => wrapper.findAllComponents(GlButton);
  const findCancelButton = () => wrapper.findComponentByTestId('cancel-button');
  const findBackButton = () => wrapper.findComponentByTestId('back-button');
  const findNextButton = () => wrapper.findComponentByTestId('next-button');
  const findAlert = () => wrapper.findComponent(GlAlert);
  const findExitModal = () => wrapper.findComponentByTestId('exit-confirmation-modal');

  beforeEach(async () => {
    await createComponent();
  });

  afterEach(() => {
    wrapper?.destroy();
  });

  it('renders a Cancel link-button that goes to the root route', () => {
    expect(findCancelButton().text()).toBe('Cancel');
    expect(findCancelButton().attributes('to')).toBe('/');
  });

  describe('stepper indicator', () => {
    it('renders each step', () => {
      const steps = findSteps();

      expect(steps).toHaveLength(4);
      expect(steps.at(0).text()).toContain('Select approach');
      expect(steps.at(1).text()).toContain('Select projects');
      expect(steps.at(2).text()).toContain('Select scanners');
      expect(steps.at(3).text()).toContain('Review configuration');
    });

    it('highlights the current step and shows checkmarks for completed steps', async () => {
      await createComponent({ initialRoute: ROUTE_SCANNERS });

      const steps = findSteps();

      expect(steps.at(0).classes('gl-bg-transparent')).toBe(true);
      expect(steps.at(1).classes('gl-bg-transparent')).toBe(true);
      expect(steps.at(2).classes('gl-bg-transparent')).toBe(false); // current step
      expect(steps.at(3).classes('gl-bg-transparent')).toBe(true);

      expect(findStepCheckmarks()).toHaveLength(2);
    });
  });

  describe('provides properties to child components', () => {
    it('exposes a writable "approach" property, defaults to quick setup', async () => {
      const provided = wrapper.vm.$options.provide.call(wrapper.vm);

      expect(wrapper.vm.approach).toBe(APPROACH_QUICK);
      expect(provided.enableScanners.approach).toBe(APPROACH_QUICK);

      wrapper.vm.approach = APPROACH_ADVANCED;
      await nextTick();

      expect(wrapper.vm.approach).toBe(APPROACH_ADVANCED);
      expect(provided.enableScanners.approach).toBe(APPROACH_ADVANCED);
    });
  });

  describe('quick setup (default) steps', () => {
    describe.each`
      route             | previousButtonText   | previousButtonRoute | nextButtonText           | nextButtonRoute
      ${ROUTE_APPROACH} | ${null}              | ${null}             | ${'Start quick setup'}   | ${ROUTE_REVIEW}
      ${ROUTE_REVIEW}   | ${'Select approach'} | ${ROUTE_APPROACH}   | ${'Apply configuration'} | ${ROUTE_CONFIRMATION}
    `(
      '$route',
      ({ route, previousButtonText, previousButtonRoute, nextButtonText, nextButtonRoute }) => {
        beforeEach(async () => {
          await createComponent({ initialRoute: route, approach: APPROACH_QUICK });
        });

        it(`shows ${previousButtonText || 'no'} previous button`, () => {
          if (previousButtonText === null) {
            expect(findBackButton().exists()).toBe(false);
          } else {
            expect(findBackButton().text()).toContain(previousButtonText);
            expect(findBackButton().props('to')).toEqual({ name: previousButtonRoute });
          }
        });

        it(`shows ${nextButtonText || 'no'} next button`, async () => {
          if (nextButtonText === null) {
            expect(findNextButton().exists()).toBe(false);
          } else {
            expect(findNextButton().text()).toContain(nextButtonText);

            findNextButton().vm.$emit('click');
            await waitForPromises();

            expect(wrapper.vm.$route.name).toBe(nextButtonRoute);
          }
        });
      },
    );
  });

  describe('advanced setup steps', () => {
    describe.each`
      route             | previousButtonText   | previousButtonRoute | nextButtonText            | nextButtonRoute
      ${ROUTE_APPROACH} | ${null}              | ${null}             | ${'Start advanced setup'} | ${ROUTE_ITEMS}
      ${ROUTE_ITEMS}    | ${'Select approach'} | ${ROUTE_APPROACH}   | ${'Select scanners'}      | ${ROUTE_SCANNERS}
      ${ROUTE_SCANNERS} | ${'Select projects'} | ${ROUTE_ITEMS}      | ${'Review configuration'} | ${ROUTE_REVIEW}
      ${ROUTE_REVIEW}   | ${'Select scanners'} | ${ROUTE_SCANNERS}   | ${'Apply configuration'}  | ${ROUTE_CONFIRMATION}
    `(
      '$route',
      ({ route, previousButtonText, previousButtonRoute, nextButtonText, nextButtonRoute }) => {
        beforeEach(async () => {
          await createComponent({ initialRoute: route, approach: APPROACH_ADVANCED });
        });

        it(`shows ${previousButtonText || 'no'} previous button`, () => {
          if (previousButtonText === null) {
            expect(findBackButton().exists()).toBe(false);
          } else {
            expect(findBackButton().text()).toContain(previousButtonText);
            expect(findBackButton().props('to')).toEqual({ name: previousButtonRoute });
          }
        });

        it(`shows ${nextButtonText || 'no'} next button`, async () => {
          if (nextButtonText === null) {
            expect(findNextButton().exists()).toBe(false);
          } else {
            expect(findNextButton().text()).toContain(nextButtonText);

            findNextButton().vm.$emit('click');
            await waitForPromises();

            expect(wrapper.vm.$route.name).toBe(nextButtonRoute);
          }
        });
      },
    );
  });

  describe('confirmation route', () => {
    it('renders only the router-view (no stepper, no footer buttons)', async () => {
      await createComponent({ initialRoute: ROUTE_CONFIRMATION });

      expect(findRouterView().exists()).toBe(true);
      expect(findSteps()).toHaveLength(0);
      expect(findButtons()).toHaveLength(0);
      expect(findExitModal().exists()).toBe(false);
    });
  });

  describe('exit confirmation modal', () => {
    const triggerLeave = (to = { fullPath: '/' }) => {
      const next = jest.fn();
      EnableScannersWizard.beforeRouteLeave.call(wrapper.vm, to, {}, next);
      return next;
    };

    it('renders the modal with the expected title, body, and actions', async () => {
      await createComponent({ initialRoute: ROUTE_ITEMS, approach: APPROACH_ADVANCED });
      const modal = findExitModal();

      expect(modal.props('title')).toBe('Exit scanner setup?');
      expect(modal.text()).toContain(
        "Your progress won't be saved. You'll need to start over if you return.",
      );
      expect(modal.props('actionPrimary')).toMatchObject({
        text: 'Exit setup',
        attributes: { variant: 'confirm' },
      });
      expect(modal.props('actionCancel')).toMatchObject({ text: 'Continue setup' });
    });

    it('starts hidden', async () => {
      await createComponent({ initialRoute: ROUTE_ITEMS, approach: APPROACH_ADVANCED });

      expect(findExitModal().props('visible')).toBe(false);
    });

    describe('when the wizard has no unsaved changes', () => {
      it.each`
        scenario                   | initialRoute          | approach
        ${'default approach step'} | ${ROUTE_APPROACH}     | ${APPROACH_QUICK}
        ${'confirmation route'}    | ${ROUTE_CONFIRMATION} | ${APPROACH_QUICK}
      `(
        'allows navigation without showing the modal from $scenario',
        async ({ initialRoute, approach }) => {
          await createComponent({ initialRoute, approach });

          const next = triggerLeave();
          await nextTick();

          expect(next).toHaveBeenCalledWith();
        },
      );
    });

    describe('when the wizard has unsaved changes', () => {
      beforeEach(async () => {
        await createComponent({ initialRoute: ROUTE_ITEMS, approach: APPROACH_ADVANCED });
      });

      it('opens the modal and blocks navigation when the user tries to leave', async () => {
        const next = triggerLeave();
        await nextTick();

        expect(next).toHaveBeenCalledWith(false);
        expect(findExitModal().props('visible')).toBe(true);
      });

      it('opens the modal when the approach has been changed from the default on the approach step', async () => {
        await createComponent({ initialRoute: ROUTE_APPROACH, approach: APPROACH_ADVANCED });

        const next = triggerLeave();
        await nextTick();

        expect(next).toHaveBeenCalledWith(false);
        expect(findExitModal().props('visible')).toBe(true);
      });

      it('navigates to the requested destination when confirming exit', async () => {
        triggerLeave({ fullPath: '/' });
        await nextTick();

        const pushSpy = jest.spyOn(router, 'push').mockResolvedValue();
        findExitModal().vm.$emit('primary');

        expect(pushSpy).toHaveBeenCalledWith('/');
      });

      it('preserves a non-default destination when confirming exit', async () => {
        triggerLeave({ fullPath: '/scanners/sast' });
        await nextTick();

        const pushSpy = jest.spyOn(router, 'push').mockResolvedValue();
        findExitModal().vm.$emit('primary');

        expect(pushSpy).toHaveBeenCalledWith('/scanners/sast');
      });

      it('hides the modal and stays on the current route when continuing setup', async () => {
        triggerLeave();
        await nextTick();
        expect(findExitModal().props('visible')).toBe(true);

        findExitModal().vm.$emit('canceled');
        await nextTick();

        expect(findExitModal().props('visible')).toBe(false);
        expect(router.currentRoute.name).toBe(ROUTE_ITEMS);
      });

      it('clears the pending destination when dismissed via backdrop or Escape', async () => {
        triggerLeave({ fullPath: '/stale-destination' });
        await nextTick();
        expect(findExitModal().props('visible')).toBe(true);

        findExitModal().vm.$emit('hidden');
        await nextTick();

        expect(findExitModal().props('visible')).toBe(false);
        expect(router.currentRoute.name).toBe(ROUTE_ITEMS);

        // A subsequent confirm should fall back to '/', not the stale destination
        const pushSpy = jest.spyOn(router, 'push').mockResolvedValue();
        findExitModal().vm.$emit('primary');

        expect(pushSpy).toHaveBeenCalledWith('/');
      });

      it('allows the second navigation attempt once exit has been confirmed', async () => {
        const blockedNext = triggerLeave();
        expect(blockedNext).toHaveBeenCalledWith(false);

        jest.spyOn(router, 'push').mockResolvedValue();
        findExitModal().vm.$emit('primary');
        await nextTick();

        const followUpNext = triggerLeave();
        expect(followUpNext).toHaveBeenCalledWith();
      });
    });
  });

  describe('beforeunload handling', () => {
    const findConfirmDialog = () => wrapper.findComponent(ConfirmUnsavedChangesDialog);

    it.each`
      scenario                          | initialRoute          | approach             | expected
      ${'on the default approach step'} | ${ROUTE_APPROACH}     | ${APPROACH_QUICK}    | ${false}
      ${'with a non-default approach'}  | ${ROUTE_APPROACH}     | ${APPROACH_ADVANCED} | ${true}
      ${'past the approach step'}       | ${ROUTE_ITEMS}        | ${APPROACH_ADVANCED} | ${true}
      ${'on the confirmation route'}    | ${ROUTE_CONFIRMATION} | ${APPROACH_QUICK}    | ${false}
    `(
      'passes hasUnsavedChanges=$expected to the confirm-unsaved-changes dialog $scenario',
      async ({ initialRoute, approach, expected }) => {
        await createComponent({ initialRoute, approach });

        expect(findConfirmDialog().props('hasUnsavedChanges')).toBe(expected);
      },
    );
  });

  describe('available scanners', () => {
    it('fetches available security scan profiles for the group', async () => {
      await createComponent();
      await waitForPromises();

      expect(availableScannersHandler).toHaveBeenCalledWith(
        expect.objectContaining({ fullPath: GROUP_FULL_PATH }),
      );
    });

    it('groups available scanners by scanType in profilesByScanType', async () => {
      await createComponent();
      await waitForPromises();

      expect(wrapper.vm.profilesByScanType).toEqual({
        SAST: [sastProfile],
        SECRET_DETECTION: [secretProfile1, secretProfile2],
      });
    });

    it('lists each distinct scan type in allScanTypes', async () => {
      await createComponent();
      await waitForPromises();

      expect(wrapper.vm.allScanTypes).toEqual(['SAST', 'SECRET_DETECTION']);
    });

    it('excludes scanners with an unsupported scan type', async () => {
      await createComponent({
        availableScannersHandler: jest.fn().mockResolvedValue({
          data: {
            group: {
              id: GROUP_GID,
              name: 'group',
              availableSecurityScanProfiles: [
                sastProfile,
                { ...sastProfile, scanType: 'UNSUPPORTED_SCAN_TYPE' },
              ],
              __typename: 'Group',
            },
          },
        }),
      });
      await waitForPromises();

      expect(wrapper.vm.allScanTypes).toEqual(['SAST']);
    });
  });

  describe('step count badges', () => {
    it('shows the selected item count on the Select projects step once completed', async () => {
      await createComponent({
        approach: APPROACH_ADVANCED,
        initialRoute: ROUTE_REVIEW,
        selectedItems: [{ id: 1 }, { id: 2 }],
      });

      expect(findSteps().at(1).text()).toContain('2');
    });

    it('shows "All" on the Select projects step when all items are selected', async () => {
      await createComponent({
        approach: APPROACH_QUICK,
        initialRoute: ROUTE_REVIEW,
        areAllItemsSelected: true,
      });

      expect(findSteps().at(1).text()).toContain('All');
    });

    it('shows the selected scanner count on the Select scanners step once completed', async () => {
      await createComponent({
        approach: APPROACH_ADVANCED,
        initialRoute: ROUTE_REVIEW,
        selectedScanners: [sastProfile, secretProfile1],
      });

      expect(findSteps().at(2).text()).toContain('2');
    });
  });

  describe('project selection', () => {
    const itemA = { id: 'gid://gitlab/Project/1', fullPath: 'group/project-a' };
    const itemB = { id: 'gid://gitlab/Project/2', fullPath: 'group/project-b' };
    const itemC = { id: 'gid://gitlab/Project/3', fullPath: 'group/project-c' };

    it('adds an item to selectedItems when toggled on', () => {
      wrapper.vm.toggleItem(itemA, true);

      expect(wrapper.vm.selectedItems).toEqual([itemA]);
    });

    it('removes an item from selectedItems when toggled off', async () => {
      await createComponent({ selectedItems: [itemA, itemB] });

      wrapper.vm.toggleItem(itemA, false);

      expect(wrapper.vm.selectedItems).toEqual([itemB]);
    });

    it('adds the visible items when toggleVisibleItems is called with selected=true', () => {
      wrapper.vm.toggleVisibleItems(true, [itemA, itemB]);

      expect(wrapper.vm.selectedItems).toEqual([itemA, itemB]);
    });

    it('removes the visible items when toggleVisibleItems is called with selected=false', async () => {
      await createComponent({ selectedItems: [itemA, itemB, itemC] });

      wrapper.vm.toggleVisibleItems(false, [itemA, itemB]);

      expect(wrapper.vm.selectedItems).toEqual([itemC]);
    });

    it('caps the selection at 100 items when selecting visible items', () => {
      const manyItems = Array.from({ length: 150 }, (_, i) => ({
        id: `gid://gitlab/Project/${i}`,
        fullPath: `group/project-${i}`,
      }));

      wrapper.vm.toggleVisibleItems(true, manyItems);

      expect(wrapper.vm.selectedItems).toHaveLength(100);
    });
  });

  describe('scanner selection', () => {
    beforeEach(async () => {
      await createComponent();
      await waitForPromises();
    });

    it('defaults to the first profile for a scan type', () => {
      expect(wrapper.vm.activeProfileForScanType('SECRET_DETECTION')).toEqual(secretProfile1);
    });

    it('returns the currently selected profile for a scan type when one is selected', async () => {
      await createComponent({ selectedScanners: [secretProfile2] });
      await waitForPromises();

      expect(wrapper.vm.activeProfileForScanType('SECRET_DETECTION')).toEqual(secretProfile2);
    });

    it('replaces the active profile for a scan type when selectScannerProfile is called', async () => {
      await createComponent({ selectedScanners: [secretProfile1] });
      await waitForPromises();

      wrapper.vm.selectScannerProfile('SECRET_DETECTION', secretProfile2);

      expect(wrapper.vm.activeProfileForScanType('SECRET_DETECTION')).toEqual(secretProfile2);
    });

    it('adds the default profile for a scan type when toggleScanner is called with checked=true', () => {
      wrapper.vm.toggleScanner('SAST', true);

      expect(wrapper.vm.selectedScanners).toEqual([sastProfile]);
    });

    it('removes all profiles for a scan type when toggleScanner is called with checked=false', async () => {
      await createComponent({ selectedScanners: [sastProfile] });
      await waitForPromises();

      wrapper.vm.toggleScanner('SAST', false);

      expect(wrapper.vm.selectedScanners).toEqual([]);
    });

    it('selects the default profile for every scan type when toggleAllScanners is called with checked=true', () => {
      wrapper.vm.toggleAllScanners(true);

      expect(wrapper.vm.selectedScanners).toEqual([sastProfile, secretProfile1]);
    });

    it('clears all selected scanners when toggleAllScanners is called with checked=false', async () => {
      await createComponent({ selectedScanners: [sastProfile, secretProfile1] });
      await waitForPromises();

      wrapper.vm.toggleAllScanners(false);

      expect(wrapper.vm.selectedScanners).toEqual([]);
    });
  });

  describe('pre-population from route query params', () => {
    it('pre-selects the scanner and all items when a scanner query param is present', async () => {
      await createComponent({
        initialRoute: ROUTE_REVIEW,
        initialRouteQuery: { scanner: 'SECRET_DETECTION' },
      });
      await waitForPromises();

      const steps = findSteps();
      expect(steps.at(1).text()).toContain('All');
      expect(steps.at(2).text()).toContain('1');
    });
  });

  describe('review step', () => {
    it('calls onSubmit when the submit button is clicked', async () => {
      const onSubmit = jest
        .spyOn(EnableScannersWizard.methods, 'onSubmit')
        .mockImplementation(() => {});
      await createComponent({ initialRoute: ROUTE_REVIEW });

      findNextButton().vm.$emit('click');

      expect(onSubmit).toHaveBeenCalled();
    });
  });

  describe('onSubmit', () => {
    it('attaches each selected profile via the attach mutation', async () => {
      await createComponent({
        initialRoute: ROUTE_REVIEW,
        selectedScanners: [sastProfile, secretProfile1],
      });

      await wrapper.vm.onSubmit();

      expect(attachHandler).toHaveBeenCalledTimes(2);
      expect(attachHandler).toHaveBeenCalledWith({
        input: expect.objectContaining({ securityScanProfileId: sastProfile.id }),
      });
      expect(attachHandler).toHaveBeenCalledWith({
        input: expect.objectContaining({ securityScanProfileId: secretProfile1.id }),
      });
    });

    it('sends the selected project IDs as projectIds for advanced setup', async () => {
      await createComponent({
        initialRoute: ROUTE_REVIEW,
        approach: APPROACH_ADVANCED,
        areAllItemsSelected: false,
        selectedItems: [{ id: 'gid://gitlab/Project/9' }],
        selectedScanners: [sastProfile],
      });

      await wrapper.vm.onSubmit();

      expect(attachHandler).toHaveBeenCalledWith({
        input: expect.objectContaining({
          projectIds: ['gid://gitlab/Project/9'],
          groupIds: [],
        }),
      });
    });

    it('sends the root group ID as groupIds for quick setup', async () => {
      await createComponent({
        initialRoute: ROUTE_REVIEW,
        areAllItemsSelected: true,
        selectedScanners: [sastProfile],
      });

      await wrapper.vm.onSubmit();

      expect(attachHandler).toHaveBeenCalledWith({
        input: expect.objectContaining({
          groupIds: [GROUP_GID],
          projectIds: [],
        }),
      });
    });

    it('navigates to the confirmation route when there are no errors', async () => {
      await createComponent({
        initialRoute: ROUTE_REVIEW,
        selectedScanners: [sastProfile],
      });

      await wrapper.vm.onSubmit();
      await waitForPromises();

      expect(wrapper.vm.$route.name).toBe(ROUTE_CONFIRMATION);
    });

    describe('on error', () => {
      it('does not navigate to confirmation when there are submit errors', async () => {
        await createComponent({
          initialRoute: ROUTE_REVIEW,
          selectedScanners: [sastProfile],
          attachHandler: attachHandlerWithErrors(['Something went wrong']),
        });

        await wrapper.vm.onSubmit();
        await waitForPromises();

        expect(wrapper.vm.$route.name).toBe(ROUTE_REVIEW);
      });

      it('collects and displays errors from all mutation responses', async () => {
        const attachHandlerWithMultipleErrors = jest
          .fn()
          .mockResolvedValueOnce({
            data: {
              securityScanProfileAttach: {
                __typename: 'SecurityScanProfileAttachPayload',
                clientMutationId: '1',
                errors: ['First profile failed'],
              },
            },
          })
          .mockResolvedValueOnce({
            data: {
              securityScanProfileAttach: {
                __typename: 'SecurityScanProfileAttachPayload',
                clientMutationId: '1',
                errors: ['Second profile failed'],
              },
            },
          });
        await createComponent({
          initialRoute: ROUTE_REVIEW,
          selectedScanners: [sastProfile, secretProfile1],
          attachHandler: attachHandlerWithMultipleErrors,
        });

        await wrapper.vm.onSubmit();
        await nextTick();

        expect(wrapper.vm.submitErrors).toEqual(['First profile failed', 'Second profile failed']);
        expect(findAlert().exists()).toBe(true);
        expect(findAlert().text()).toContain('First profile failed');
        expect(findAlert().text()).toContain('Second profile failed');
      });
    });
  });

  describe('internal events tracking', () => {
    describe('view_enable_scanners_wizard_step', () => {
      it.each`
        route                 | label
        ${ROUTE_APPROACH}     | ${'approach'}
        ${ROUTE_ITEMS}        | ${'items'}
        ${ROUTE_SCANNERS}     | ${'scanners'}
        ${ROUTE_REVIEW}       | ${'review'}
        ${ROUTE_CONFIRMATION} | ${'confirmation'}
      `('tracks $label when the wizard mounts on $route', async ({ route, label }) => {
        const { trackEventSpy } = bindInternalEventDocument(document.body);
        await createComponent({ initialRoute: route });

        expect(trackEventSpy).toHaveBeenCalledWith(
          'view_enable_scanners_wizard_step',
          { label },
          undefined,
        );
      });

      it('tracks each step when the route changes', async () => {
        await createComponent({ initialRoute: ROUTE_APPROACH, approach: APPROACH_ADVANCED });
        const { trackEventSpy } = bindInternalEventDocument(wrapper.element);

        await router.push({ name: ROUTE_ITEMS });

        expect(trackEventSpy).toHaveBeenCalledWith(
          'view_enable_scanners_wizard_step',
          { label: 'items' },
          undefined,
        );
      });
    });

    describe('start_enable_scanners_wizard', () => {
      it.each`
        approach             | label
        ${APPROACH_QUICK}    | ${'quick'}
        ${APPROACH_ADVANCED} | ${'advanced'}
      `('tracks $label when advancing from the approach step', async ({ approach, label }) => {
        await createComponent({ initialRoute: ROUTE_APPROACH, approach });
        const { trackEventSpy } = bindInternalEventDocument(wrapper.element);

        findNextButton().vm.$emit('click');
        await waitForPromises();

        expect(trackEventSpy).toHaveBeenCalledWith(
          'start_enable_scanners_wizard',
          { label },
          undefined,
        );
      });

      it('does not emit per-scanner select events when quick setup auto-selects scanners', async () => {
        await createComponent({ initialRoute: ROUTE_APPROACH, approach: APPROACH_QUICK });
        await waitForPromises();
        const { trackEventSpy } = bindInternalEventDocument(wrapper.element);

        findNextButton().vm.$emit('click');
        await waitForPromises();

        expect(trackEventSpy).not.toHaveBeenCalledWith(
          'select_enable_scanners_wizard_scanner',
          expect.anything(),
          expect.anything(),
        );
      });
    });

    describe('select_enable_scanners_wizard_item / deselect_enable_scanners_wizard_item', () => {
      const itemA = { id: 'gid://gitlab/Project/1', fullPath: 'group/project-a' };
      const itemB = { id: 'gid://gitlab/Project/2', fullPath: 'group/project-b' };

      it('tracks when toggleItem selects an item', () => {
        const { trackEventSpy } = bindInternalEventDocument(wrapper.element);

        wrapper.vm.toggleItem(itemA, true);

        expect(trackEventSpy).toHaveBeenCalledWith(
          'select_enable_scanners_wizard_item',
          {},
          undefined,
        );
      });

      it('tracks when toggleItem deselects an item', async () => {
        await createComponent({ selectedItems: [itemA] });
        const { trackEventSpy } = bindInternalEventDocument(wrapper.element);

        wrapper.vm.toggleItem(itemA, false);

        expect(trackEventSpy).toHaveBeenCalledWith(
          'deselect_enable_scanners_wizard_item',
          {},
          undefined,
        );
      });

      it('tracks a single select event when toggleVisibleItems selects all visible', () => {
        const { trackEventSpy } = bindInternalEventDocument(wrapper.element);

        wrapper.vm.toggleVisibleItems(true, [itemA, itemB]);

        const itemSelectCalls = trackEventSpy.mock.calls.filter(
          ([eventName]) => eventName === 'select_enable_scanners_wizard_item',
        );
        expect(itemSelectCalls).toHaveLength(1);
        expect(itemSelectCalls[0]).toEqual(['select_enable_scanners_wizard_item', {}, undefined]);
      });

      it('tracks a single deselect event when toggleVisibleItems deselects all visible', async () => {
        await createComponent({ selectedItems: [itemA, itemB] });
        const { trackEventSpy } = bindInternalEventDocument(wrapper.element);

        wrapper.vm.toggleVisibleItems(false, [itemA, itemB]);

        const itemDeselectCalls = trackEventSpy.mock.calls.filter(
          ([eventName]) => eventName === 'deselect_enable_scanners_wizard_item',
        );
        expect(itemDeselectCalls).toHaveLength(1);
        expect(itemDeselectCalls[0]).toEqual([
          'deselect_enable_scanners_wizard_item',
          {},
          undefined,
        ]);
      });
    });

    describe('select_enable_scanners_wizard_scanner / deselect_enable_scanners_wizard_scanner', () => {
      beforeEach(async () => {
        await createComponent();
        await waitForPromises();
      });

      it('tracks the scan type when toggleScanner selects a scanner', () => {
        const { trackEventSpy } = bindInternalEventDocument(wrapper.element);

        wrapper.vm.toggleScanner('SAST', true);

        expect(trackEventSpy).toHaveBeenCalledWith(
          'select_enable_scanners_wizard_scanner',
          { label: 'SAST' },
          undefined,
        );
      });

      it('tracks the scan type when toggleScanner deselects a scanner', async () => {
        await createComponent({ selectedScanners: [sastProfile] });
        await waitForPromises();
        const { trackEventSpy } = bindInternalEventDocument(wrapper.element);

        wrapper.vm.toggleScanner('SAST', false);

        expect(trackEventSpy).toHaveBeenCalledWith(
          'deselect_enable_scanners_wizard_scanner',
          { label: 'SAST' },
          undefined,
        );
      });

      it('tracks each newly-selected scan type when toggleAllScanners selects all', () => {
        const { trackEventSpy } = bindInternalEventDocument(wrapper.element);

        wrapper.vm.toggleAllScanners(true);

        expect(trackEventSpy).toHaveBeenCalledWith(
          'select_enable_scanners_wizard_scanner',
          { label: 'SAST' },
          undefined,
        );
        expect(trackEventSpy).toHaveBeenCalledWith(
          'select_enable_scanners_wizard_scanner',
          { label: 'SECRET_DETECTION' },
          undefined,
        );
      });

      it('tracks each previously-selected scan type when toggleAllScanners deselects all', async () => {
        await createComponent({ selectedScanners: [sastProfile, secretProfile1] });
        await waitForPromises();
        const { trackEventSpy } = bindInternalEventDocument(wrapper.element);

        wrapper.vm.toggleAllScanners(false);

        expect(trackEventSpy).toHaveBeenCalledWith(
          'deselect_enable_scanners_wizard_scanner',
          { label: 'SAST' },
          undefined,
        );
        expect(trackEventSpy).toHaveBeenCalledWith(
          'deselect_enable_scanners_wizard_scanner',
          { label: 'SECRET_DETECTION' },
          undefined,
        );
      });
    });

    describe('apply_enable_scanners_wizard', () => {
      it.each`
        approach             | label
        ${APPROACH_QUICK}    | ${'quick'}
        ${APPROACH_ADVANCED} | ${'advanced'}
      `(
        'tracks the chosen approach ($label) when the configuration is submitted',
        async ({ approach, label }) => {
          await createComponent({
            initialRoute: ROUTE_REVIEW,
            approach,
            selectedScanners: [sastProfile],
            areAllItemsSelected: approach === APPROACH_QUICK,
          });
          const { trackEventSpy } = bindInternalEventDocument(wrapper.element);

          await wrapper.vm.onSubmit();

          expect(trackEventSpy).toHaveBeenCalledWith(
            'apply_enable_scanners_wizard',
            { label },
            undefined,
          );
        },
      );
    });

    describe('abandon_enable_scanners_wizard', () => {
      it('tracks the step the user abandoned from when exit is confirmed', async () => {
        await createComponent({ initialRoute: ROUTE_ITEMS, approach: APPROACH_ADVANCED });
        const { trackEventSpy } = bindInternalEventDocument(wrapper.element);
        jest.spyOn(router, 'push').mockResolvedValue();

        EnableScannersWizard.beforeRouteLeave.call(wrapper.vm, { fullPath: '/' }, {}, jest.fn());
        await nextTick();
        findExitModal().vm.$emit('primary');

        expect(trackEventSpy).toHaveBeenCalledWith(
          'abandon_enable_scanners_wizard',
          { label: 'items' },
          undefined,
        );
      });
    });
  });
});
