import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { GlCard, GlButton } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { createAlert } from '~/alert';
import { AVAILABILITY_OPTIONS } from 'ee/ai/settings/constants';
import DuoConfigurationSettingsInfoCard from 'ee/ai/settings/components/duo_configuration_settings_info_card.vue';
import DuoConfigurationSettingsRow from 'ee/ai/settings/components/duo_configuration_settings_row.vue';
import getDuoSettingsQuery from 'ee/ai/graphql/get_ai_settings.query.graphql';
import { DUO_ENTERPRISE } from 'ee/constants/duo';

Vue.use(VueApollo);

jest.mock('~/lib/utils/url_utility');
jest.mock('~/alert');

describe('DuoConfigurationSettingsInfoCard', () => {
  let wrapper;

  const defaultDuoSettings = {
    aiGatewayUrl: 'http://0.0.0.0:5052',
    aiGatewayTimeoutSeconds: 60,
    duoCoreFeaturesEnabled: true,
    duoCliEnabled: true,
    duoAgentPlatformServiceUrl: '',
    selfHostedDuoAgentPlatformServiceSecure: false,
  };

  const createDuoSettingsApolloHandler = (overrides = {}) => [
    [
      getDuoSettingsQuery,
      jest.fn().mockResolvedValue({
        data: {
          duoSettings: { ...defaultDuoSettings, ...overrides },
        },
      }),
    ],
  ];

  const createComponent = (
    {
      exposeDuoAgentPlatformServiceUrl = false,
      canManageSelfHostedModels = false,
      duoConfigurationPath = '/gitlab_duo/configuration',
      isSaaS = false,
      duoAvailability = AVAILABILITY_OPTIONS.DEFAULT_ON,
      directCodeSuggestionsEnabled = true,
      experimentFeaturesEnabled = true,
      betaSelfHostedModelsEnabled = true,
      areExperimentSettingsAllowed = true,
      areDuoCoreFeaturesEnabled = true,
      apolloHandlers = createDuoSettingsApolloHandler(),
    } = {},
    props = {},
  ) => {
    const mockApollo = createMockApollo(apolloHandlers);

    wrapper = shallowMountExtended(DuoConfigurationSettingsInfoCard, {
      apolloProvider: mockApollo,
      provide: {
        exposeDuoAgentPlatformServiceUrl,
        canManageSelfHostedModels,
        duoConfigurationPath,
        isSaaS,
        duoAvailability,
        directCodeSuggestionsEnabled,
        experimentFeaturesEnabled,
        betaSelfHostedModelsEnabled,
        areExperimentSettingsAllowed,
        areDuoCoreFeaturesEnabled,
      },
      propsData: {
        activeDuoTier: DUO_ENTERPRISE,
        ...props,
      },
    });

    return waitForPromises();
  };

  const findCard = () => wrapper.findAllComponents(GlCard);
  const findConfigurationButton = () => wrapper.findComponent(GlButton);
  const findDuoConfigurationRows = () => wrapper.findAllComponents(DuoConfigurationSettingsRow);
  const findAllDuoConfigurationRowTitleProps = () =>
    findDuoConfigurationRows().wrappers.map((row) =>
      row.props('duoConfigurationSettingsRowTypeTitle'),
    );
  const findDuoConfigurationRowTitlePropByRowIdx = (idx) =>
    findDuoConfigurationRows().at(idx).props('duoConfigurationSettingsRowTypeTitle');
  const findDuoConfigurationSettingsInfo = () =>
    wrapper.findByTestId('duo-configuration-settings-info');
  const findConfigurationStatus = () => wrapper.findByTestId('configuration-status');
  const findDuoCoreConfigValue = () => findDuoConfigurationRows().at(0).props('configValue');

  describe('on component loaded', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders the GlCard component', () => {
      expect(findCard().exists()).toBe(true);
    });

    it('renders the title correctly', () => {
      expect(findDuoConfigurationSettingsInfo().text()).toBe('GitLab Duo Enterprise');
    });

    it('renders the configuration button with correct href', () => {
      expect(findConfigurationButton().exists()).toBe(true);
      expect(findConfigurationButton().attributes('href')).toBe('/gitlab_duo/configuration');
      expect(findConfigurationButton().text()).toBe('Change configuration');
    });
  });

  describe('availability status', () => {
    it.each([
      [AVAILABILITY_OPTIONS.DEFAULT_ON, 'On by default'],
      [AVAILABILITY_OPTIONS.DEFAULT_OFF, 'Off by default'],
      [AVAILABILITY_OPTIONS.NEVER_ON, 'Always off'],
    ])('displays correct status for %s', async (status, expected) => {
      await createComponent({ duoAvailability: status });
      expect(findConfigurationStatus().text()).toBe(expected);
    });
  });

  describe('DuoConfigurationSettingsRow rendering', () => {
    describe('for self-managed instance', () => {
      it('renders the correct rows', async () => {
        await createComponent({ isSaaS: false });

        expect(findDuoConfigurationRows()).toHaveLength(3);
        expect(findDuoConfigurationRowTitlePropByRowIdx(0)).toBe(
          'GitLab Duo Core available to all users',
        );
        expect(findDuoConfigurationRowTitlePropByRowIdx(1)).toBe('Experiment and beta features');
        expect(findDuoConfigurationRowTitlePropByRowIdx(2)).toBe('Direct connections');
      });

      describe('with self-hosted Duo enabled', () => {
        it('renders the correct rows', async () => {
          await createComponent({ isSaaS: false, canManageSelfHostedModels: true });

          expect(findDuoConfigurationRows()).toHaveLength(6);
          expect(findDuoConfigurationRowTitlePropByRowIdx(0)).toBe(
            'GitLab Duo Core available to all users',
          );
          expect(findDuoConfigurationRowTitlePropByRowIdx(1)).toBe('Experiment and beta features');
          expect(findDuoConfigurationRowTitlePropByRowIdx(2)).toBe('Direct connections');
          expect(findDuoConfigurationRowTitlePropByRowIdx(3)).toBe(
            'Self-hosted beta models and features',
          );
          expect(findDuoConfigurationRowTitlePropByRowIdx(4)).toBe('AI logs');
          expect(findDuoConfigurationRowTitlePropByRowIdx(5)).toBe('Local AI gateway URL');
        });

        describe('when AI gateway URL is not set', () => {
          it('does not render the config row', async () => {
            await createComponent({
              isSaaS: false,
              canManageSelfHostedModels: true,
              apolloHandlers: createDuoSettingsApolloHandler({ aiGatewayUrl: null }),
            });

            expect(findDuoConfigurationRows()).toHaveLength(5);
            expect(findAllDuoConfigurationRowTitleProps()).not.toContain('Local AI gateway URL');
          });
        });

        describe('Local URL for the GitLab Duo Agent Platform service', () => {
          describe('when exposed', () => {
            describe('when URL is set', () => {
              beforeEach(() => {
                return createComponent({
                  isSaaS: false,
                  canManageSelfHostedModels: true,
                  apolloHandlers: createDuoSettingsApolloHandler({
                    duoAgentPlatformServiceUrl: 'duo-agent-platform:50052',
                  }),
                  exposeDuoAgentPlatformServiceUrl: true,
                });
              });

              it('renders the Local URL for the GitLab Duo Agent Platform service row', () => {
                expect(findDuoConfigurationRows()).toHaveLength(8);
                expect(findDuoConfigurationRowTitlePropByRowIdx(6)).toBe(
                  'Local URL for the GitLab Duo Agent Platform service',
                );
                expect(findDuoConfigurationRows().at(6).props('configValue')).toBe(
                  'duo-agent-platform:50052',
                );
              });

              it('renders the Duo Agent Platform secure connection row', () => {
                expect(findDuoConfigurationRowTitlePropByRowIdx(7)).toBe(
                  'Secure connection (TLS) for GitLab Duo Agent Platform service',
                );
                expect(findDuoConfigurationRows().at(7).props('configValue')).toBe(false);
              });
            });

            describe('when URL is not set', () => {
              it('does not render the Local URL for the GitLab Duo Agent Platform service row', async () => {
                await createComponent({
                  isSaaS: false,
                  canManageSelfHostedModels: true,
                  apolloHandlers: createDuoSettingsApolloHandler({
                    duoAgentPlatformServiceUrl: '',
                  }),
                  exposeDuoAgentPlatformServiceUrl: true,
                });

                expect(findDuoConfigurationRows()).toHaveLength(6);
                expect(findAllDuoConfigurationRowTitleProps()).not.toContain(
                  'Local URL for the GitLab Duo Agent Platform service',
                );
                expect(findAllDuoConfigurationRowTitleProps()).not.toContain(
                  'Secure connection (TLS) for GitLab Duo Agent Platform service',
                );
              });
            });

            describe('when URL is null', () => {
              it('does not render the Local URL for the GitLab Duo Agent Platform service row', async () => {
                await createComponent({
                  isSaaS: false,
                  canManageSelfHostedModels: true,
                  apolloHandlers: createDuoSettingsApolloHandler({
                    duoAgentPlatformServiceUrl: null,
                  }),
                  exposeDuoAgentPlatformServiceUrl: true,
                });

                expect(findDuoConfigurationRows()).toHaveLength(6);
                expect(findAllDuoConfigurationRowTitleProps()).not.toContain(
                  'Local URL for the GitLab Duo Agent Platform service',
                );
                expect(findAllDuoConfigurationRowTitleProps()).not.toContain(
                  'Secure connection (TLS) for GitLab Duo Agent Platform service',
                );
              });
            });
          });

          describe('when not exposed', () => {
            it('does not render the Duo Agent Platform Service URL row', async () => {
              await createComponent({
                isSaaS: false,
                canManageSelfHostedModels: true,
                apolloHandlers: createDuoSettingsApolloHandler({
                  duoAgentPlatformServiceUrl: 'duo-agent-platform:50052',
                }),
                exposeDuoAgentPlatformServiceUrl: false,
              });

              expect(findDuoConfigurationRows()).toHaveLength(6);
              expect(findAllDuoConfigurationRowTitleProps()).not.toContain(
                'Local URL for the GitLab Duo Agent Platform service',
              );
            });
          });
        });
      });
    });

    it('renders fewer rows for SaaS instance', async () => {
      await createComponent({ isSaaS: true });

      expect(findDuoConfigurationRows()).toHaveLength(2);
      expect(findDuoConfigurationRowTitlePropByRowIdx(0)).toBe(
        'GitLab Duo Core available to all users',
      );
      expect(findDuoConfigurationRowTitlePropByRowIdx(1)).toBe('Experiment and beta features');
    });

    it('passes correct props to configuration rows', async () => {
      await createComponent();
      expect(findDuoConfigurationRows().at(0).props('configValue')).toBe(true);
      expect(findDuoConfigurationRows().at(1).props('configValue')).toBe(true);
      expect(findDuoConfigurationRows().at(2).props('configValue')).toBe(true);
    });

    describe('when Duo Core features are enabled and availability is on', () => {
      it('sets config value for Duo Core to true', async () => {
        await createComponent({
          duoAvailability: AVAILABILITY_OPTIONS.DEFAULT_ON,
          areDuoCoreFeaturesEnabled: true,
        });
        expect(findDuoCoreConfigValue()).toBe(true);
      });
    });

    describe('when Duo Core features are enabled and availability is off', () => {
      it('sets config value for Duo Core to false', async () => {
        await createComponent({
          duoAvailability: AVAILABILITY_OPTIONS.NEVER_ON,
          areDuoCoreFeaturesEnabled: true,
        });
        expect(findDuoCoreConfigValue()).toBe(false);
      });
    });

    describe('when Duo Core features are disabled and availability is on', () => {
      it('sets config value for Duo Core to false', async () => {
        await createComponent({
          duoAvailability: AVAILABILITY_OPTIONS.DEFAULT_ON,
          areDuoCoreFeaturesEnabled: false,
        });
        expect(findDuoCoreConfigValue()).toBe(false);
      });
    });

    describe('when the GraphQL query fails', () => {
      it('renders gracefully with default values and shows an error alert', async () => {
        await createComponent({
          canManageSelfHostedModels: true,
          apolloHandlers: [
            [getDuoSettingsQuery, jest.fn().mockRejectedValue(new Error('GraphQL error'))],
          ],
        });

        expect(findCard().exists()).toBe(true);
        expect(findConfigurationButton().exists()).toBe(true);
        expect(createAlert).toHaveBeenCalledWith(
          expect.objectContaining({
            message: 'An error occurred while loading GitLab Duo settings. Please try again.',
            captureError: true,
          }),
        );
      });
    });
  });
});
