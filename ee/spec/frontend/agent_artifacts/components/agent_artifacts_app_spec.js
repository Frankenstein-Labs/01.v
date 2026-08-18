import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import AgentArtifactsApp from 'ee/agent_artifacts/components/agent_artifacts_app.vue';
import AgentArtifactsTable from 'ee/agent_artifacts/components/agent_artifacts_table.vue';
import AgentArtifactsFilteredSearch from 'ee/agent_artifacts/components/agent_artifacts_filtered_search.vue';
import SessionDetailsDrawer from 'ee/agent_artifacts/components/session_details_drawer.vue';

describe('AgentArtifactsApp', () => {
  let wrapper;

  const mockItem = { id: 'gid://gitlab/Ai::DuoWorkflows::Workflow/1', name: 'test-agent' };
  const mockEvent = { id: 'event-1', eventName: 'tool_execution' };

  const createComponent = () => {
    wrapper = shallowMountExtended(AgentArtifactsApp);
  };

  const findTable = () => wrapper.findComponent(AgentArtifactsTable);
  const findDrawer = () => wrapper.findComponent(SessionDetailsDrawer);

  const openDrawer = () => findTable().vm.$emit('row-click', mockItem);

  beforeEach(() => {
    createComponent();
  });

  it('renders the agent artifacts filtered search', () => {
    expect(wrapper.findComponent(AgentArtifactsFilteredSearch).exists()).toBe(true);
  });

  it('renders the agent artifacts table', () => {
    expect(wrapper.findComponent(AgentArtifactsTable).exists()).toBe(true);
  });

  describe('SessionDetailsDrawer', () => {
    it('does not render drawer when no active item', () => {
      expect(wrapper.findComponent(SessionDetailsDrawer).exists()).toBe(false);
    });

    it('renders drawer when row is clicked', async () => {
      await wrapper.findComponent(AgentArtifactsTable).vm.$emit('row-click', mockItem);

      expect(wrapper.findComponent(SessionDetailsDrawer).exists()).toBe(true);
      expect(wrapper.findComponent(SessionDetailsDrawer).props('activeItem')).toEqual(mockItem);
    });

    it('closes drawer when close event is emitted', async () => {
      await wrapper.findComponent(AgentArtifactsTable).vm.$emit('row-click', mockItem);
      expect(wrapper.findComponent(SessionDetailsDrawer).exists()).toBe(true);

      await wrapper.findComponent(SessionDetailsDrawer).vm.$emit('close');
      expect(wrapper.findComponent(SessionDetailsDrawer).exists()).toBe(false);
    });
  });

  describe('filtering', () => {
    it('closes session details drawer when filter changes', async () => {
      await wrapper
        .findComponent(AgentArtifactsTable)
        .vm.$emit('row-click', { id: '1', name: 'test-agent' });
      expect(wrapper.findComponent(SessionDetailsDrawer).exists()).toBe(true);

      await wrapper
        .findComponent(AgentArtifactsFilteredSearch)
        .vm.$emit('filter', { name: 'another-agent' });

      expect(wrapper.findComponent(SessionDetailsDrawer).exists()).toBe(false);
    });
  });

  describe('event selection', () => {
    it('sets the selected event when the drawer emits select', async () => {
      await openDrawer();

      await findDrawer().vm.$emit('select', mockEvent);

      expect(findDrawer().props('selectedEvent')).toEqual(mockEvent);
    });

    it('clears the selected event when the drawer emits back', async () => {
      await openDrawer();
      await findDrawer().vm.$emit('select', mockEvent);

      await findDrawer().vm.$emit('back');

      expect(findDrawer().props('selectedEvent')).toBeNull();
    });

    it('clears the selected event when another session row is clicked', async () => {
      const otherItem = { id: 'gid://gitlab/Ai::DuoWorkflows::Workflow/2', name: 'other-agent' };

      await openDrawer();
      await findDrawer().vm.$emit('select', mockEvent);

      await findTable().vm.$emit('row-click', otherItem);

      expect(findDrawer().props('activeItem')).toEqual(otherItem);
      expect(findDrawer().props('selectedEvent')).toBeNull();
    });

    it('clears the selected event when the same session row is clicked again', async () => {
      await openDrawer();
      await findDrawer().vm.$emit('select', mockEvent);

      await findTable().vm.$emit('row-click', mockItem);

      expect(findDrawer().props('selectedEvent')).toBeNull();
    });
  });
});
