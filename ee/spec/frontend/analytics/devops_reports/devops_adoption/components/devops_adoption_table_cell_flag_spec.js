import { shallowMount } from '@vue/test-utils';
import { nextTick } from 'vue';
import DevopsAdoptionTableCellFlag from 'ee/analytics/devops_reports/devops_adoption/components/devops_adoption_table_cell_flag.vue';

describe('DevopsAdoptionTableCellFlag', () => {
  let wrapper;

  const createComponent = (props) => {
    wrapper = shallowMount(DevopsAdoptionTableCellFlag, {
      propsData: {
        enabled: true,
        name: 'MRs',
        ...props,
      },
    });
  };

  describe('enabled', () => {
    beforeEach(() => createComponent());

    it('matches the snapshot', () => {
      expect(wrapper.element).toMatchSnapshot();
    });

    describe('when the enabled flag is changed to false', () => {
      beforeEach(async () => {
        wrapper.setProps({ enabled: false });

        await nextTick();
      });

      it('matches the snapshot', () => {
        expect(wrapper.element).toMatchSnapshot();
      });
    });

    describe('with a variant specified', () => {
      beforeEach(() => {
        createComponent({ variant: 'primary' });
      });

      it('matches the snapshot', () => {
        expect(wrapper.element).toMatchSnapshot();
      });
    });
  });

  describe('disabled', () => {
    beforeEach(() => createComponent({ enabled: false }));

    it('matches the snapshot', () => {
      expect(wrapper.element).toMatchSnapshot();
    });

    describe('when the enabled flag is changed to true', () => {
      beforeEach(async () => {
        wrapper.setProps({ enabled: true });

        await nextTick();
      });

      it('matches the snapshot', () => {
        expect(wrapper.element).toMatchSnapshot();
      });
    });
  });
});
