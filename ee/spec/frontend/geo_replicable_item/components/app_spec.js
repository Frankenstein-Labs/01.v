import { GlLoadingIcon, GlSprintf } from '@gitlab/ui';
import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { ACTION_TYPES } from 'ee/geo_shared/constants';
import GeoReplicableItemApp from 'ee/geo_replicable_item/components/app.vue';
import GeoReplicableItemRegistryInfo from 'ee/geo_replicable_item/components/geo_replicable_item_registry_info.vue';
import GeoReplicableItemReplicationInfo from 'ee/geo_replicable_item/components/geo_replicable_item_replication_info.vue';
import GeoReplicableItemVerificationInfo from 'ee/geo_replicable_item/components/geo_replicable_item_verification_info.vue';
import buildReplicableItemQuery from 'ee/geo_replicable_item/graphql/replicable_item_query_builder';
import replicableTypeUpdateMutation from 'ee/geo_shared/graphql/replicable_type_update_mutation.graphql';
import { createAlert } from '~/alert';
import toast from '~/vue_shared/plugins/global_toast';
import {
  MOCK_REPLICABLE_CLASS,
  MOCK_REPLICABLE_WITH_VERIFICATION,
  MOCK_REPLICABLE_WITHOUT_VERIFICATION,
} from '../mock_data';

jest.mock('~/alert');
jest.mock('~/vue_shared/plugins/global_toast');

Vue.use(VueApollo);

describe('GeoReplicableItemApp', () => {
  let wrapper;

  const defaultProps = {
    replicableClass: MOCK_REPLICABLE_CLASS,
    replicableItemId: '1',
  };

  const createComponent = ({ props = {}, handler, mutationHandler } = {}) => {
    const propsData = {
      ...defaultProps,
      ...props,
    };

    const query = buildReplicableItemQuery(
      propsData.replicableClass.graphqlRegistryIdType,
      propsData.replicableClass.graphqlFieldName,
      propsData.replicableClass.verificationEnabled,
    );

    const mockReplicable = propsData.replicableClass.verificationEnabled
      ? MOCK_REPLICABLE_WITH_VERIFICATION
      : MOCK_REPLICABLE_WITHOUT_VERIFICATION;

    const apolloQueryHandler =
      handler ||
      jest.fn().mockResolvedValue({
        data: {
          geoNode: {
            [defaultProps.replicableClass.graphqlFieldName]: {
              nodes: [
                {
                  ...mockReplicable,
                },
              ],
            },
          },
        },
      });

    const apolloMutationHandler =
      mutationHandler ||
      jest.fn().mockResolvedValue({
        data: {
          geoRegistriesUpdate: {
            errors: [],
          },
        },
      });

    const apolloProvider = createMockApollo([
      [query, apolloQueryHandler],
      [replicableTypeUpdateMutation, apolloMutationHandler],
    ]);

    wrapper = shallowMountExtended(GeoReplicableItemApp, {
      propsData,
      apolloProvider,
      stubs: {
        GlSprintf,
      },
    });
  };

  const findGlLoadingIcon = () => wrapper.findComponent(GlLoadingIcon);
  const findRegistryInfoComponent = () => wrapper.findComponent(GeoReplicableItemRegistryInfo);
  const findReplicationInfoComponent = () =>
    wrapper.findComponent(GeoReplicableItemReplicationInfo);
  const findVerificationInfoComponent = () =>
    wrapper.findComponent(GeoReplicableItemVerificationInfo);

  describe('loading state', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders GlLoadingIcon initially', () => {
      expect(findGlLoadingIcon().exists()).toBe(true);
    });
  });

  describe('registry information', () => {
    beforeEach(async () => {
      createComponent();

      await waitForPromises();
    });

    it('renders registry info component with correct props', () => {
      expect(findRegistryInfoComponent().props('replicableItem')).toStrictEqual(
        MOCK_REPLICABLE_WITH_VERIFICATION,
      );
      expect(findRegistryInfoComponent().props('registryId')).toBe(
        `${MOCK_REPLICABLE_CLASS.graphqlRegistryClass}/${defaultProps.replicableItemId}`,
      );
      expect(findRegistryInfoComponent().props('replicableClass')).toStrictEqual(
        MOCK_REPLICABLE_CLASS,
      );
    });
  });

  describe('replication information', () => {
    beforeEach(async () => {
      createComponent();

      await waitForPromises();
    });

    it('renders replication info component', () => {
      expect(findReplicationInfoComponent().exists()).toBe(true);
    });
  });

  describe('verification information', () => {
    describe('when verification is disabled', () => {
      beforeEach(async () => {
        createComponent({
          props: { replicableClass: { ...MOCK_REPLICABLE_CLASS, verificationEnabled: false } },
        });

        await waitForPromises();
      });

      it('does not render the verification info component', () => {
        expect(findVerificationInfoComponent().exists()).toBe(false);
      });
    });

    describe('when verification is enabled', () => {
      beforeEach(async () => {
        createComponent({
          props: { replicableClass: { ...MOCK_REPLICABLE_CLASS, verificationEnabled: true } },
        });

        await waitForPromises();
      });

      it('renders the verification info component', () => {
        expect(findVerificationInfoComponent().exists()).toBe(true);
      });
    });
  });

  describe('reverify functionality', () => {
    const mockMutationHandler = jest.fn().mockResolvedValue({
      data: {
        geoRegistriesUpdate: {
          errors: [],
        },
      },
    });

    beforeEach(async () => {
      createComponent({
        props: { replicableClass: { ...MOCK_REPLICABLE_CLASS, verificationEnabled: true } },
        mutationHandler: mockMutationHandler,
      });

      await waitForPromises();
    });

    describe('when reverify is successful', () => {
      let refetchSpy;

      beforeEach(async () => {
        refetchSpy = jest.spyOn(wrapper.vm.$apollo.queries.replicableItem, 'refetch');

        findVerificationInfoComponent().vm.$emit('reverify');
        await waitForPromises();
      });

      it('calls the mutation with correct variables', () => {
        expect(mockMutationHandler).toHaveBeenCalledWith({
          action: ACTION_TYPES.REVERIFY,
          registryId: MOCK_REPLICABLE_WITH_VERIFICATION.id,
        });
      });

      it('shows success toast message', () => {
        expect(toast).toHaveBeenCalledWith('Reverify was scheduled successfully');
      });

      it('re-fetches the query data', () => {
        expect(refetchSpy).toHaveBeenCalled();
      });
    });

    describe('when reverify fails', () => {
      beforeEach(async () => {
        const errorMutationHandler = jest.fn().mockRejectedValue(new Error('GraphQL Error'));

        createComponent({
          props: { replicableClass: { ...MOCK_REPLICABLE_CLASS, verificationEnabled: true } },
          mutationHandler: errorMutationHandler,
        });

        await waitForPromises();
      });

      it('shows error alert and not toast', async () => {
        findVerificationInfoComponent().vm.$emit('reverify');
        await waitForPromises();

        expect(createAlert).toHaveBeenCalledWith({
          message: 'There was an error executing the Reverify mutation',
          error: expect.any(Error),
          captureError: true,
        });

        expect(toast).not.toHaveBeenCalled();
      });
    });

    describe('when verification is disabled', () => {
      beforeEach(async () => {
        createComponent({
          props: { replicableClass: { ...MOCK_REPLICABLE_CLASS, verificationEnabled: false } },
        });

        await waitForPromises();
      });

      it('does not render verification info component', () => {
        expect(findVerificationInfoComponent().exists()).toBe(false);
      });
    });
  });

  describe('resync functionality', () => {
    const mockMutationHandler = jest.fn().mockResolvedValue({
      data: {
        geoRegistriesUpdate: {
          errors: [],
        },
      },
    });

    beforeEach(async () => {
      createComponent({
        mutationHandler: mockMutationHandler,
      });

      await waitForPromises();
    });

    describe('when resync is successful', () => {
      let refetchSpy;

      beforeEach(async () => {
        refetchSpy = jest.spyOn(wrapper.vm.$apollo.queries.replicableItem, 'refetch');

        findReplicationInfoComponent().vm.$emit('resync');
        await waitForPromises();
      });

      it('calls the mutation with correct variables', () => {
        expect(mockMutationHandler).toHaveBeenCalledWith({
          action: ACTION_TYPES.RESYNC,
          registryId: MOCK_REPLICABLE_WITH_VERIFICATION.id,
        });
      });

      it('shows success toast message', () => {
        expect(toast).toHaveBeenCalledWith('Resync was scheduled successfully');
      });

      it('re-fetches the query data', () => {
        expect(refetchSpy).toHaveBeenCalled();
      });
    });

    describe('when resync fails', () => {
      beforeEach(async () => {
        const errorMutationHandler = jest.fn().mockRejectedValue(new Error('GraphQL Error'));

        createComponent({
          mutationHandler: errorMutationHandler,
        });

        await waitForPromises();
      });

      it('shows error alert and not toast', async () => {
        findReplicationInfoComponent().vm.$emit('resync');
        await waitForPromises();

        expect(createAlert).toHaveBeenCalledWith({
          message: 'There was an error executing the Resync mutation',
          error: expect.any(Error),
          captureError: true,
        });

        expect(toast).not.toHaveBeenCalled();
      });
    });
  });

  describe('error handling', () => {
    it('displays error message when Apollo query fails', async () => {
      const errorMessage = new Error('GraphQL Error');
      const handler = jest.fn().mockRejectedValue(errorMessage);
      createComponent({ handler });

      await waitForPromises();

      expect(createAlert).toHaveBeenCalledWith({
        message: "There was an error fetching this replicable's details",
        captureError: true,
        error: errorMessage,
      });
    });
  });
});
