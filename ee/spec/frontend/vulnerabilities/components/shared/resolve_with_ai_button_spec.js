import { GlButton } from '@gitlab/ui';
import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { createMockSubscription } from 'mock-apollo-client';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import aiResolveVulnerability from 'ee/vulnerabilities/graphql/ai_resolve_vulnerability.mutation.graphql';
import aiResponseSubscription from 'ee/graphql_shared/subscriptions/ai_completion_response.subscription.graphql';
import securityFindingCreateVulnerability from 'ee/vulnerabilities/graphql/security_finding_create_vulnerability.mutation.graphql';
import ResolveWithAiButton from 'ee/vulnerabilities/components/shared/resolve_with_ai_button.vue';
import ResolveWithAiInfoPopover from 'ee/vulnerabilities/components/shared/resolve_with_ai_info_popover.vue';
import {
  MUTATION_AI_ACTION_DEFAULT_RESPONSE,
  getAiSubscriptionResponse,
} from 'ee_jest/vulnerabilities/mock_data';

Vue.use(VueApollo);

describe('ee/vulnerabilities/components/shared/resolve_with_ai_button.vue', () => {
  let wrapper;

  const createWrapper = ({ apolloProvider, propsData } = {}) => {
    wrapper = shallowMountExtended(ResolveWithAiButton, {
      apolloProvider,
      propsData: {
        mergeRequestId: '1',
        findingUuid: '1',
        vulnerabilityId: '1',
        ...propsData,
      },
    });
  };

  const findButton = () => wrapper.findComponent(GlButton);
  const findInfoPopover = () => wrapper.findComponent(ResolveWithAiInfoPopover);
  const clickButton = () => findButton().vm.$emit('click');

  describe('initial render', () => {
    it('renders a "Resolve with AI" confirm button with an tanuki-ai icon and a title that describes the feature', () => {
      createWrapper();

      expect(findButton().text()).toBe('Resolve with AI');
      expect(findButton().props()).toMatchObject({
        icon: 'tanuki-ai',
        variant: 'confirm',
      });
    });

    it('does not have a loading state by default', () => {
      createWrapper();

      expect(findButton().props('loading')).toBe(false);
    });
  });

  describe('info popover', () => {
    it('is connected to the button', () => {
      createWrapper();
      const buttonId = findButton().attributes('id');

      expect(buttonId).toEqual(expect.any(String));
      expect(buttonId).not.toHaveLength(0);
      expect(findInfoPopover().props('target')).toBe(buttonId);
    });

    it.each([true, false])(
      'gets passed "show-public-project-warning" when it is "%s"',
      (showPublicProjectWarning) => {
        createWrapper({
          propsData: { showPublicProjectWarning },
        });

        expect(findInfoPopover().props('showPublicProjectWarning')).toBe(showPublicProjectWarning);
      },
    );
  });

  describe('when the button is clicked', () => {
    let mockSubscription;
    let subscriptionSpy;

    const sendSubscriptionMessage = (aiCompletionResponse = null) =>
      mockSubscription.next({ data: { aiCompletionResponse } });

    const createWrapperWithApollo = ({ responseHandlers = {}, ...wrapperOptions } = {}) => {
      mockSubscription = createMockSubscription();
      subscriptionSpy = jest.fn().mockReturnValue(mockSubscription);

      const apolloProvider = createMockApollo([
        [
          aiResolveVulnerability,
          responseHandlers.aiResolveVulnerability || MUTATION_AI_ACTION_DEFAULT_RESPONSE,
        ],
        [
          securityFindingCreateVulnerability,
          responseHandlers.securityFindingCreateVulnerability || jest.fn().mockResolvedValue({}),
        ],
      ]);
      apolloProvider.defaultClient.setRequestHandler(aiResponseSubscription, subscriptionSpy);

      createWrapper({ apolloProvider, ...wrapperOptions });
    };

    beforeEach(() => {
      // this is needed because the component uses it for the subscription's current user variable
      gon.current_user_id = 1;
    });

    it('shows a loading state', async () => {
      createWrapperWithApollo();

      clickButton();

      await nextTick();

      expect(findButton().props('loading')).toBe(true);
    });

    it('does not render the info popover', async () => {
      createWrapperWithApollo();

      expect(findInfoPopover().exists()).toBe(true);

      clickButton();
      await nextTick();

      expect(findInfoPopover().exists()).toBe(false);
    });

    describe('vulnerability finding', () => {
      it('does not create a vulnerability finding for the finding when the given finding has a vulnerability ID', () => {
        const findingCreationSpy = jest.fn().mockResolvedValue({});
        createWrapperWithApollo({
          responseHandlers: { securityFindingCreateVulnerability: findingCreationSpy },
        });

        clickButton();

        expect(findingCreationSpy).not.toHaveBeenCalled();
      });

      it('creates a vulnerability finding for the finding when the given finding does not have a vulnerability ID', () => {
        const findingCreationSpy = jest.fn().mockResolvedValue({
          data: {
            securityFindingCreateVulnerability: {
              vulnerability: {
                id: '1',
              },
            },
          },
        });

        createWrapperWithApollo({
          responseHandlers: {
            securityFindingCreateVulnerability: findingCreationSpy,
          },
          propsData: { vulnerabilityId: undefined },
        });

        expect(findingCreationSpy).not.toHaveBeenCalled();

        clickButton();

        expect(findingCreationSpy).toHaveBeenCalledWith({
          uuid: '1',
        });
      });

      describe('error handling', () => {
        const setupErrorFindingCreationSpy = () => {
          const findingCreationSpy = jest.fn().mockRejectedValue(new Error('creation error'));
          createWrapperWithApollo({
            responseHandlers: {
              securityFindingCreateVulnerability: findingCreationSpy,
            },
            propsData: { vulnerabilityId: undefined },
          });
          return findingCreationSpy;
        };

        it('emits an error when the "securityFindingCreateVulnerability" errors', async () => {
          const findingCreationSpy = setupErrorFindingCreationSpy();

          expect(wrapper.emitted('error')).toBeUndefined();

          clickButton();

          await waitForPromises();

          expect(findingCreationSpy).toHaveBeenCalledWith({ uuid: '1' });
          expect(wrapper.emitted('error')).toHaveLength(1);
          expect(wrapper.emitted('error')[0][0]).toEqual(new Error('creation error'));
          expect(wrapper.emitted('resolve-start')).toBeUndefined();
        });

        it('prevents error message from being cleared by "resolve-start" when "securityFindingCreateVulnerability" errors', async () => {
          setupErrorFindingCreationSpy();

          expect(wrapper.emitted('error')).toBeUndefined();
          expect(wrapper.emitted('resolve-start')).toBeUndefined();

          clickButton();

          await waitForPromises();
          expect(wrapper.emitted('error')).toHaveLength(1);
          expect(wrapper.emitted('resolve-start')).toBeUndefined();
        });
      });
    });

    describe('resolve with AI', () => {
      it('emits "resolve-start" event when the button is clicked', () => {
        createWrapperWithApollo();

        expect(wrapper.emitted('resolve-start')).toBeUndefined();

        clickButton();

        expect(wrapper.emitted('resolve-start')).toHaveLength(1);
      });

      it('starts the "aiResponse" subscription', () => {
        createWrapperWithApollo();

        expect(subscriptionSpy).not.toHaveBeenCalled();

        clickButton();

        expect(subscriptionSpy).toHaveBeenCalled();
      });

      it('calls the "aiResolveVulnerability" mutation when the subscription is ready', async () => {
        createWrapperWithApollo();

        clickButton();

        expect(MUTATION_AI_ACTION_DEFAULT_RESPONSE).not.toHaveBeenCalled();

        sendSubscriptionMessage();
        await waitForPromises();

        expect(MUTATION_AI_ACTION_DEFAULT_RESPONSE).toHaveBeenCalled();
      });

      it.each`
        mergeRequestId | expectedToHaveProperty
        ${'1'}         | ${true}
        ${null}        | ${false}
      `(
        'includes mergeRequestId in the mutation variables when mergeRequestId is $mergeRequestId: $expectedToHaveProperty',
        async ({ mergeRequestId, expectedToHaveProperty }) => {
          const aiResolveVulnerabilitySpy = jest.fn().mockResolvedValue({
            data: { aiAction: { errors: [] } },
          });

          createWrapperWithApollo({
            responseHandlers: { aiResolveVulnerability: aiResolveVulnerabilitySpy },
            propsData: { mergeRequestId },
          });

          clickButton();
          sendSubscriptionMessage();
          await waitForPromises();

          const resolveVulnerabilityVariables = aiResolveVulnerabilitySpy.mock.calls[0][0];

          if (expectedToHaveProperty) {
            expect(resolveVulnerabilityVariables).toHaveProperty(
              'vulnerableMergeRequestId',
              `gid://gitlab/MergeRequest/${mergeRequestId}`,
            );
          } else {
            expect(resolveVulnerabilityVariables).not.toHaveProperty('vulnerableMergeRequestId');
          }
        },
      );

      it('emits a "success" event when the subscription response returns the correct content', async () => {
        createWrapperWithApollo();

        clickButton();

        expect(wrapper.emitted('success')).toBeUndefined();

        const resultUrl = 'http://gitlab.com/project/merge_requests/2#note_1';
        sendSubscriptionMessage(getAiSubscriptionResponse(resultUrl));
        await waitForPromises();

        expect(wrapper.emitted('success')).toHaveLength(1);
        expect(wrapper.emitted('success')[0]).toEqual([resultUrl]);
      });

      describe('error handling', () => {
        it('emits an error when the subscription errors', async () => {
          createWrapperWithApollo();

          clickButton();

          expect(wrapper.emitted('error')).toBeUndefined();

          const errors = ['subscription error'];
          sendSubscriptionMessage({
            ...getAiSubscriptionResponse(null),
            errors,
          });
          await waitForPromises();

          expect(wrapper.emitted('error')).toHaveLength(1);
          expect(wrapper.emitted('error')[0]).toEqual(errors);
        });

        it('emits an error when the "aiResolveVulnerability" mutation errors', async () => {
          const aiResolveVulnerabilitySpy = jest
            .fn()
            .mockRejectedValue(new Error('mutation error'));

          createWrapperWithApollo({
            responseHandlers: { aiResolveVulnerability: aiResolveVulnerabilitySpy },
          });

          expect(wrapper.emitted('error')).toBeUndefined();

          clickButton();
          sendSubscriptionMessage(null);
          await waitForPromises();

          expect(wrapper.emitted('error')).toHaveLength(1);
          expect(wrapper.emitted('error')[0]).toEqual(['mutation error']);
        });
      });
    });
  });
});
