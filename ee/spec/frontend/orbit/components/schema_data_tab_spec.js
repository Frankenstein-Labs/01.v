import { mount } from '@vue/test-utils';
import { useMockInternalEventsTracking } from 'helpers/tracking_internal_events_helper';
import SchemaDataTab from 'ee/orbit/components/schema_data_tab.vue';

describe('SchemaDataTab', () => {
  let wrapper;

  const schema = {
    nodes: [{ name: 'Project', domain: 'core' }],
    edges: [{ name: 'BELONGS_TO', source_type: 'Project', target_type: 'Project' }],
  };

  const createComponent = () => {
    wrapper = mount(SchemaDataTab, {
      propsData: { schema },
    });
  };

  describe('tracking', () => {
    const { bindInternalEventDocument } = useMockInternalEventsTracking();

    beforeEach(() => {
      createComponent();
    });

    it('tracks click_orbit_schema_item with label "entity" when an entity button is clicked', async () => {
      const { trackEventSpy } = bindInternalEventDocument(wrapper.element);

      await wrapper.find('[data-testid="schema-entity-Project"]').trigger('click');

      expect(trackEventSpy).toHaveBeenCalledWith(
        'click_orbit_schema_item',
        { label: 'entity' },
        undefined,
      );
    });

    it('tracks click_orbit_schema_item with label "relationship" when a relationship button is clicked', async () => {
      const { trackEventSpy } = bindInternalEventDocument(wrapper.element);

      await wrapper.find('[data-testid="schema-relationship-BELONGS_TO"]').trigger('click');

      expect(trackEventSpy).toHaveBeenCalledWith(
        'click_orbit_schema_item',
        { label: 'relationship' },
        undefined,
      );
    });

    it('does not track when clicking an already-selected entity (deselect)', async () => {
      const { trackEventSpy } = bindInternalEventDocument(wrapper.element);
      await wrapper.find('[data-testid="schema-entity-Project"]').trigger('click');
      trackEventSpy.mockClear();

      await wrapper.find('[data-testid="schema-entity-Project"]').trigger('click');

      expect(trackEventSpy).not.toHaveBeenCalled();
    });

    it('does not track when clicking an already-selected relationship (deselect)', async () => {
      const { trackEventSpy } = bindInternalEventDocument(wrapper.element);
      await wrapper.find('[data-testid="schema-relationship-BELONGS_TO"]').trigger('click');
      trackEventSpy.mockClear();

      await wrapper.find('[data-testid="schema-relationship-BELONGS_TO"]').trigger('click');

      expect(trackEventSpy).not.toHaveBeenCalled();
    });
  });
});
