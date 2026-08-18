import { nextTick } from 'vue';
import { GlCollapsibleListbox, GlTruncate, GlIcon, GlButton, GlAlert } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import StatusMapping from 'ee/groups/settings/work_items/custom_status/change_lifecycle/status_mapping.vue';
import { mockLifecycles } from '../../mock_data';

describe('StatusMapping', () => {
  let wrapper;

  const findListboxes = () => wrapper.findAllComponents(GlCollapsibleListbox);
  const findListboxByIndex = (index) => findListboxes().at(index);
  const findStatusIcons = () => wrapper.findAllComponents(GlIcon);
  const findToggleButtons = () => wrapper.findAllComponents(GlButton);
  const findDescriptionText = () => wrapper.find('.gl-text-subtle');
  const findCurrentStatusTableHeading = () => wrapper.findByTestId('current-status-mapping-header');
  const findNewStatusTableHeading = () => wrapper.findByTestId('new-status-mapping-header');
  const findCurrentStatuses = () => wrapper.findAllByTestId('current-status');
  const findError = () => wrapper.findComponent(GlAlert);

  const mockCurrentLifecycle = {
    ...mockLifecycles[0],
  };

  const mockSelectedLifecycle = {
    ...mockLifecycles[1],
  };

  const mockStatusMappings = [
    {
      oldStatusId: 'gid://gitlab/WorkItems::Statuses::Custom::Status/165',
      newStatusId: 'gid://gitlab/WorkItems::Statuses::Custom::Status/162',
    },
    {
      oldStatusId: 'gid://gitlab/WorkItems::Statuses::Custom::Status/166',
      newStatusId: 'gid://gitlab/WorkItems::Statuses::Custom::Status/163',
    },
    {
      oldStatusId: 'gid://gitlab/WorkItems::Statuses::Custom::Status/167',
      newStatusId: 'gid://gitlab/WorkItems::Statuses::Custom::Status/164',
    },
  ];

  const defaultProps = {
    currentLifecycle: mockCurrentLifecycle,
    selectedLifecycle: mockSelectedLifecycle,
  };

  const createComponent = (props = {}) => {
    wrapper = shallowMountExtended(StatusMapping, {
      propsData: { ...defaultProps, ...props },
      stubs: {
        GlCollapsibleListbox,
        GlIcon,
      },
    });
  };

  describe('Component Initialization', () => {
    beforeEach(() => {
      createComponent();
    });

    it('displays descriptive text', () => {
      expect(findDescriptionText().text()).toContain(
        'Select a status to use for each current status. Items using these statuses will automatically be updated to the new status.',
      );
    });

    it('renders table headers', () => {
      expect(findCurrentStatusTableHeading().text()).toBe('Current status');
      expect(findNewStatusTableHeading().text()).toBe('New status');
    });

    it('emits initialise-mapping event on mount', () => {
      expect(wrapper.emitted('initialise-mapping')).toHaveLength(1);
      expect(wrapper.emitted('initialise-mapping')[0][0]).toEqual(mockStatusMappings);
    });

    it('shows error when we have it in props', async () => {
      createComponent({ stepError: 'Some error while updating mapping' });

      expect(findError().exists()).toBe(true);
      findError().vm.$emit('dismiss');
      await nextTick();

      expect(wrapper.emitted('error-dismissed')).toHaveLength(1);
    });
  });

  describe('Status Rows Rendering', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders correct number of status rows', () => {
      const findStatusRows = () => wrapper.findAll('.status-row');
      expect(findStatusRows()).toHaveLength(mockCurrentLifecycle.statuses.length);
    });

    it('displays current status information correctly', () => {
      mockCurrentLifecycle.statuses.forEach((status, index) => {
        expect(findCurrentStatuses().at(index).findComponent(GlTruncate).props('text')).toBe(
          status.name,
        );
      });
    });

    it('renders status icons with correct properties', () => {
      // Should have icons for current statuses + selected statuses + dropdown icons
      expect(findStatusIcons()).toHaveLength(14);
    });

    it('renders listboxes for each status', () => {
      const listboxes = findListboxes();
      expect(listboxes).toHaveLength(mockCurrentLifecycle.statuses.length);
    });
  });

  describe('Status Selection', () => {
    beforeEach(() => {
      createComponent();
    });

    it('sets correct initial selected values for listboxes', () => {
      const listboxes = findListboxes();

      listboxes.wrappers.forEach((listbox, index) => {
        const expectedStatusId = mockStatusMappings[index].newStatusId;
        expect(listbox.props('selected')).toBe(expectedStatusId);
      });
    });

    it('handles status selection change', async () => {
      const firstListbox = findListboxByIndex(0);
      const newStatusId = 'new-status-2';

      await firstListbox.vm.$emit('select', newStatusId);

      expect(wrapper.emitted('mapping-updated')).toHaveLength(1);
      const emittedMappings = wrapper.emitted('mapping-updated')[0][0];
      expect(emittedMappings[0].newStatusId).toBe(newStatusId);
    });

    it('updates internal status mappings when selection changes', async () => {
      const firstListbox = findListboxByIndex(0);
      const newStatusId = 'new-status-3';

      await firstListbox.vm.$emit('select', newStatusId);

      // Check that internal data is updated by checking computed properties
      const updatedToggleText = firstListbox.text();
      expect(updatedToggleText).toContain('Fatima Kutch');
    });

    it('preserves other mappings when one is changed', async () => {
      const secondListbox = findListboxByIndex(1);
      const newStatusId = 'new-status-1';

      await secondListbox.vm.$emit('select', newStatusId);

      const emittedMappings = wrapper.emitted('mapping-updated')[0][0];
      // First and third mappings should remain unchanged
      expect(emittedMappings[0].newStatusId).toBe(mockStatusMappings[0].newStatusId);
      expect(emittedMappings[2].newStatusId).toBe(mockStatusMappings[2].newStatusId);
      // Second mapping should be updated
      expect(emittedMappings[1].newStatusId).toBe(newStatusId);
    });
  });

  describe('Listbox Configuration', () => {
    beforeEach(() => {
      createComponent();
    });

    it('configures listboxes with correct props', () => {
      const firstListbox = findListboxByIndex(0);

      expect(firstListbox.props()).toMatchObject({
        block: true,
        searchable: true,
        headerText: 'Select new status',
      });
    });

    it('passes eligible items to listboxes', () => {
      const listboxes = findListboxes();

      listboxes.wrappers.forEach((listbox) => {
        expect(listbox.props('items')).toEqual(
          expect.arrayContaining([
            expect.objectContaining({
              text: expect.any(String),
              value: expect.any(String),
              color: expect.any(String),
              iconName: expect.any(String),
            }),
          ]),
        );
      });
    });
  });

  describe('Edge Cases', () => {
    it('handles empty current lifecycle statuses', () => {
      const emptyCurrentLifecycle = {
        ...mockCurrentLifecycle,
        statuses: [],
      };

      createComponent({ currentLifecycle: emptyCurrentLifecycle });

      const listboxes = findListboxes();
      expect(listboxes).toHaveLength(0);
    });
  });

  describe('Custom Template Slots', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders custom toggle template', () => {
      const toggleButtons = findToggleButtons();
      expect(toggleButtons).toHaveLength(mockCurrentLifecycle.statuses.length);
    });

    it('configures toggle button correctly', () => {
      const firstToggleButton = findToggleButtons().at(0);
      expect(firstToggleButton.props('buttonTextClasses')).toBe(
        'gl-w-full gl-flex gl-justify-between',
      );
    });
  });

  describe('Listbox Search Functionality', () => {
    beforeEach(() => {
      createComponent();
    });

    it('handles search input and updates listbox items', async () => {
      const secondListBox = findListboxByIndex(1);
      const searchTerm = 'Ester';

      // Get initial items
      const initialItems = secondListBox.props('items');

      secondListBox.vm.$emit('search', searchTerm);
      await nextTick();

      const updatedItems = secondListBox.props('items');
      expect(initialItems).not.toHaveLength(updatedItems.length);

      // Items should be filtered based on search term
      updatedItems.forEach((item) => {
        expect(item.text.toLowerCase()).toContain(searchTerm.toLowerCase());
      });
    });

    it('shows all items when search term is empty', async () => {
      const secondListBox = findListboxByIndex(1);

      // First apply a search filter
      secondListBox.vm.$emit('search', 'specific-term');
      await nextTick();

      const filteredItems = secondListBox.props('items');

      expect(filteredItems).toHaveLength(0);

      // Then clear the search
      await secondListBox.vm.$emit('search', '');
      await nextTick();

      const items = secondListBox.props('items');

      expect(items).toHaveLength(2);
    });

    it('triggers search event when user searches', async () => {
      const firstListbox = findListboxByIndex(0);
      const searchTerm = 'test search';

      firstListbox.vm.$emit('search', searchTerm);
      await nextTick();

      expect(firstListbox.emitted('search')).toEqual([[searchTerm]]);
    });

    it('maintains independent search for each listbox', async () => {
      const firstListbox = findListboxByIndex(0);
      const secondListbox = findListboxByIndex(1);
      const firstSearchTerm = 'first';
      const secondSearchTerm = 'Ester';

      // Search in first listbox
      await firstListbox.vm.$emit('search', firstSearchTerm);
      await nextTick();

      // Search in second listbox
      await secondListbox.vm.$emit('search', secondSearchTerm);
      await nextTick();

      const firstItems = firstListbox.props('items');
      const secondItems = secondListbox.props('items');

      // Each listbox should have its own filtered results
      expect(firstItems).toHaveLength(0);
      expect(secondItems).toHaveLength(1);

      // Verify they can have different results
      expect(firstItems).not.toEqual(secondItems);
    });
  });
});
