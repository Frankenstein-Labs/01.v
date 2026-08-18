import { GlDrawer } from '@gitlab/ui';
import { nextTick } from 'vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import AddPanelDrawer from 'ee/explore/analytics_dashboards/components/add_panel_drawer.vue';
import DataExplorer from 'ee/explore/analytics_dashboards/components/data_explorer.vue';

jest.mock('~/lib/utils/dom_utils', () => ({
  getContentWrapperHeight: () => '123',
}));

describe('AddPanelDrawer', () => {
  let wrapper;

  const createComponent = (props = {}) => {
    wrapper = shallowMountExtended(AddPanelDrawer, {
      propsData: {
        open: false,
        ...props,
      },
    });
  };

  const findDrawer = () => wrapper.findComponent(GlDrawer);
  const findDataExplorer = () => wrapper.findComponent(DataExplorer);
  const findEmptyQueryModal = () => wrapper.findComponentByTestId('empty-query-modal');
  const findPendingChangesModal = () => wrapper.findComponentByTestId('pending-changes-modal');
  const findAddToDashboardButton = () => wrapper.findComponentByTestId('add-to-dashboard-button');
  const findCancelButton = () => wrapper.findComponentByTestId('add-panel-cancel-button');

  const inputQuery = (query) => findDataExplorer().vm.$emit('input', query);
  const submitQuery = (query) => findDataExplorer().vm.$emit('submit', query);

  const enterValidQuery = async (query = 'type = Issue') => {
    inputQuery(query);
    submitQuery(query);
    await nextTick();
  };

  beforeEach(() => {
    createComponent();
  });

  it('renders the drawer with the correct header height', () => {
    expect(findDrawer().exists()).toBe(true);
    expect(findDrawer().props('headerHeight')).toBe('123');
  });

  it('passes the open prop through to the drawer', () => {
    createComponent({ open: true });

    expect(findDrawer().props('open')).toBe(true);
  });

  it('renders the data explorer in the drawer body', () => {
    expect(findDataExplorer().exists()).toBe(true);
  });

  it('binds the working query to the data explorer', async () => {
    expect(findDataExplorer().props('query')).toBe('');

    inputQuery('type = Issue');
    await nextTick();

    expect(findDataExplorer().props('query')).toBe('type = Issue');
  });

  describe('actions', () => {
    it('renders the "Add to dashboard" button', () => {
      expect(findAddToDashboardButton().exists()).toBe(true);
      expect(findAddToDashboardButton().text()).toBe('Add to dashboard');
    });

    it('renders the "Cancel" button', () => {
      expect(findCancelButton().exists()).toBe(true);
      expect(findCancelButton().text()).toBe('Cancel');
    });

    it('emits close when the cancel button is clicked', () => {
      findCancelButton().vm.$emit('click');

      expect(wrapper.emitted('close')).toHaveLength(1);
    });
  });

  describe('when the query is valid and has been run', () => {
    beforeEach(() => enterValidQuery());

    it('adds the panel directly without confirmation when "Add to dashboard" is clicked', () => {
      findAddToDashboardButton().vm.$emit('click');

      expect(findEmptyQueryModal().props('visible')).toBe(false);
      expect(findPendingChangesModal().props('visible')).toBe(false);
      expect(wrapper.emitted('add-panel')).toHaveLength(1);
    });

    it('emits add-panel with the title and the query wrapped in a visualization', async () => {
      await enterValidQuery('      type = Issue AND state = opened \n ');

      findAddToDashboardButton().vm.$emit('click');

      expect(wrapper.emitted('add-panel')).toEqual([
        [
          {
            title: 'Untitled',
            visualization: {
              type: 'Glql',
              options: {},
              data: {
                type: 'glql',
                query: {
                  glql: 'type = Issue AND state = opened',
                },
              },
            },
          },
        ],
      ]);
    });

    it('emits add-panel with the title parsed from the query frontmatter', async () => {
      const query = ['---', 'title: Open issues', '---', 'type = Issue AND state = opened'].join(
        '\n',
      );

      inputQuery(query);
      submitQuery(query);
      await nextTick();

      findAddToDashboardButton().vm.$emit('click');

      expect(wrapper.emitted('add-panel')[0][0]).toMatchObject({
        title: 'Open issues',
      });
    });
  });

  describe('when the query is empty', () => {
    beforeEach(async () => {
      findAddToDashboardButton().vm.$emit('click');
      await nextTick();
    });

    it('shows the empty query modal and does not add the panel', () => {
      expect(findEmptyQueryModal().props('visible')).toBe(true);
      expect(findEmptyQueryModal().props('title')).toBe('Query required');
      expect(findEmptyQueryModal().text()).toContain(
        'Enter and run a query to see results before adding the panel to the dashboard.',
      );
      expect(wrapper.emitted('add-panel')).toBeUndefined();
    });

    it('has no action that can add the panel', () => {
      expect(findEmptyQueryModal().props('actionPrimary')).toBeNull();
    });

    it('hides the modal when it is closed', async () => {
      findEmptyQueryModal().vm.$emit('hidden');
      await nextTick();

      expect(findEmptyQueryModal().props('visible')).toBe(false);
    });
  });

  describe('when the query has pending changes', () => {
    beforeEach(async () => {
      inputQuery('type = Issue');
      await nextTick();

      findAddToDashboardButton().vm.$emit('click');
      await nextTick();
    });

    it('shows the pending changes confirmation modal', () => {
      expect(findPendingChangesModal().props('visible')).toBe(true);
      expect(findPendingChangesModal().props('title')).toBe('Add panel with unverified changes?');
      expect(findPendingChangesModal().text()).toContain(
        "You haven't run the updated query. The panel will use the current query text, which may differ from the preview.",
      );
      expect(wrapper.emitted('add-panel')).toBeUndefined();
    });

    describe('when the dialog is confirmed', () => {
      beforeEach(() => {
        findPendingChangesModal().vm.$emit('primary');
      });

      it('adds the panel with the current input query', () => {
        expect(wrapper.emitted('add-panel')).toEqual([
          [
            {
              title: 'Untitled',
              visualization: {
                type: 'Glql',
                options: {},
                data: {
                  type: 'glql',
                  query: {
                    glql: 'type = Issue',
                  },
                },
              },
            },
          ],
        ]);
      });
    });

    describe('when the dialog is cancelled', () => {
      beforeEach(async () => {
        findPendingChangesModal().vm.$emit('hidden');
        await nextTick();
      });

      it('does not add the panel', () => {
        expect(wrapper.emitted('add-panel')).toBeUndefined();
      });

      it('hides the warning modal', () => {
        expect(findPendingChangesModal().props('visible')).toBe(false);
      });
    });
  });

  it('closes the empty query modal and emits close when the drawer is closed', async () => {
    findAddToDashboardButton().vm.$emit('click');
    await nextTick();
    expect(findEmptyQueryModal().props('visible')).toBe(true);

    findDrawer().vm.$emit('close');
    await nextTick();
    expect(findEmptyQueryModal().props('visible')).toBe(false);
    expect(wrapper.emitted('close')).toHaveLength(1);
  });

  it('closes the pending changes modal and emits close when the drawer is closed', async () => {
    inputQuery('type = Issue');
    await nextTick();
    findAddToDashboardButton().vm.$emit('click');
    await nextTick();
    expect(findPendingChangesModal().props('visible')).toBe(true);

    findDrawer().vm.$emit('close');
    await nextTick();
    expect(findPendingChangesModal().props('visible')).toBe(false);
    expect(wrapper.emitted('close')).toHaveLength(1);
  });
});
