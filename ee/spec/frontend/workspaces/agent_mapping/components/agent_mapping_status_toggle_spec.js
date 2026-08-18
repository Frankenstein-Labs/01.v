import { GlModal, GlButton } from '@gitlab/ui';
import AgentMappingStatusToggle from 'ee_component/workspaces/agent_mapping/components/agent_mapping_status_toggle.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { MAPPED_CLUSTER_AGENT, UNMAPPED_CLUSTER_AGENT, NAMESPACE_ID } from '../../mock_data';

describe('workspaces/agent_mapping/components/agent_mapping_status_toggle', () => {
  let wrapper;

  const buildWrapper = ({ propsData = {} } = {}) => {
    wrapper = shallowMountExtended(AgentMappingStatusToggle, {
      propsData: {
        namespaceId: NAMESPACE_ID,
        ...propsData,
      },
    });
  };
  const findToggleButton = () => wrapper.findComponent(GlButton);
  const findConfirmBlockModal = () => wrapper.findComponent(GlModal);

  it('adds a primary action to the block modal', () => {
    buildWrapper({ propsData: { agent: MAPPED_CLUSTER_AGENT } });

    expect(findConfirmBlockModal().props('actionPrimary')).toEqual({
      text: 'Block agent',
      attributes: {
        variant: 'danger',
      },
    });
  });

  it.each`
    agent                     | buttonLabel
    ${MAPPED_CLUSTER_AGENT}   | ${'Block'}
    ${UNMAPPED_CLUSTER_AGENT} | ${'Allow'}
  `('displays $buttonLabel when agent is $agent', ({ agent, buttonLabel }) => {
    buildWrapper({ propsData: { agent } });

    expect(findToggleButton().text()).toContain(buttonLabel);
  });

  it.each`
    agent                     | modalActionPrimary                             | modalTitle
    ${MAPPED_CLUSTER_AGENT}   | ${{ text: 'Block agent', variant: 'danger' }}  | ${'Block this agent for all group members'}
    ${UNMAPPED_CLUSTER_AGENT} | ${{ text: 'Allow agent', variant: 'confirm' }} | ${'Allow this agent for all group members?'}
  `(
    'customizes confirmation modal based on agent status',
    ({ agent, modalActionPrimary, modalTitle }) => {
      buildWrapper({ propsData: { agent } });

      expect(findConfirmBlockModal().props().actionPrimary).toMatchObject({
        text: modalActionPrimary.text,
        attributes: {
          variant: modalActionPrimary.variant,
        },
      });
      expect(findConfirmBlockModal().props().title).toContain(modalTitle);
    },
  );

  describe('when clicking toggle', () => {
    beforeEach(() => {
      buildWrapper({ propsData: { agent: MAPPED_CLUSTER_AGENT } });
    });

    it('makes confirm block modal visible', async () => {
      await findToggleButton().vm.$emit('click');

      expect(findConfirmBlockModal().props('visible')).toBe(true);
    });
  });

  describe('when confirm block modal triggers primary event', () => {
    it('triggers toggle event', async () => {
      buildWrapper({ propsData: { agent: MAPPED_CLUSTER_AGENT } });
      await findConfirmBlockModal().vm.$emit('primary');

      expect(wrapper.emitted('toggle')).toHaveLength(1);
    });
  });

  it.each([true, false])('sets toggle button as loading based on loading property', (loading) => {
    buildWrapper({ propsData: { agent: MAPPED_CLUSTER_AGENT, loading } });

    expect(findToggleButton().props('loading')).toBe(loading);
  });
});
