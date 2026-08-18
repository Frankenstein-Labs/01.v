import { GlSprintf } from '@gitlab/ui';
import Vue from 'vue';
import VueApollo from 'vue-apollo';
import createMockApollo from 'helpers/mock_apollo_helper';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { stubComponent } from 'helpers/stub_component';
import CreateGranularPersonalAccessTokenForm from '~/personal_access_tokens/components/create_granular_token/create_granular_personal_access_token_form.vue';
import PersonalAccessTokenPermissionsSelector from '~/personal_access_tokens/components/create_granular_token/personal_access_token_permissions_selector.vue';
import createGranularPersonalAccessTokenMutation from '~/personal_access_tokens/graphql/create_granular_personal_access_token.mutation.graphql';
import getAccessTokenPermissions from '~/personal_access_tokens/graphql/get_access_token_permissions.query.graphql';

jest.mock('~/alert');

Vue.use(VueApollo);

describe('CreateGranularPersonalAccessTokenForm - EE', () => {
  let wrapper;
  let mockApollo;

  const mockMutationHandler = jest.fn().mockResolvedValue({ data: {} });
  const mockPermissionsHandler = jest
    .fn()
    .mockResolvedValue({ data: { accessTokenPermissions: [] } });

  const createComponent = ({ provide = {} } = {}) => {
    mockApollo = createMockApollo([
      [createGranularPersonalAccessTokenMutation, mockMutationHandler],
      [getAccessTokenPermissions, mockPermissionsHandler],
    ]);

    wrapper = shallowMountExtended(CreateGranularPersonalAccessTokenForm, {
      apolloProvider: mockApollo,
      provide: {
        accessTokenMaxDate: '2025-12-31',
        accessTokenTableUrl: '/-/personal_access_tokens',
        ...provide,
      },
      stubs: {
        GlSprintf,
        PersonalAccessTokenPermissionsSelector: stubComponent(
          PersonalAccessTokenPermissionsSelector,
          {
            template: '<div><slot name="header-actions" /></div>',
          },
        ),
        AskDapPermissions: true,
      },
    });
  };

  const findAskDapPermissions = () => wrapper.findComponent({ name: 'AskDapPermissions' });
  const findPermissionsSelector = () =>
    wrapper.findComponent(PersonalAccessTokenPermissionsSelector);

  describe('Duo permission suggestions', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders the AskDapPermissions component', () => {
      expect(findAskDapPermissions().exists()).toBe(true);
    });

    const emptyByScope = () => ({ namespace: [], user: [], instance: [] });

    describe('permissions-selected event', () => {
      it('passes boundary-keyed selected permissions to the permission selector', async () => {
        await findAskDapPermissions().vm.$emit('permissions-selected', {
          ...emptyByScope(),
          namespace: ['read_project'],
        });

        expect(findPermissionsSelector().props('aiPermissions')).toEqual({
          suggested: { namespace: ['read_project'], user: [], instance: [] },
          removed: emptyByScope(),
        });
      });

      it('replaces previous selections on each emission', async () => {
        await findAskDapPermissions().vm.$emit('permissions-selected', {
          ...emptyByScope(),
          namespace: ['read_project'],
        });
        await findAskDapPermissions().vm.$emit('permissions-selected', {
          ...emptyByScope(),
          namespace: ['write_project'],
        });

        expect(findPermissionsSelector().props('aiPermissions')).toEqual({
          suggested: { namespace: ['write_project'], user: [], instance: [] },
          removed: emptyByScope(),
        });
      });
    });

    describe('permissions-cleared event', () => {
      it('passes boundary-keyed cleared permissions to the permission selector', async () => {
        await findAskDapPermissions().vm.$emit('permissions-cleared', {
          ...emptyByScope(),
          namespace: ['read_project'],
        });

        expect(findPermissionsSelector().props('aiPermissions')).toEqual({
          suggested: emptyByScope(),
          removed: { namespace: ['read_project'], user: [], instance: [] },
        });
      });
    });
  });
});
