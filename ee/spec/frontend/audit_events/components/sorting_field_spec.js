import { GlCollapsibleListbox, GlListboxItem } from '@gitlab/ui';
import { mount } from '@vue/test-utils';
import SortingField from 'ee/audit_events/components/sorting_field.vue';

describe('SortingField component', () => {
  let wrapper;

  const createComponent = (props = {}) => {
    wrapper = mount(SortingField, {
      propsData: { ...props },
    });
  };

  const findGlCollapsibleListbox = () => wrapper.findComponent(GlCollapsibleListbox);
  const findAllGlListboxItems = () => wrapper.findAllComponents(GlListboxItem);

  beforeEach(() => {
    createComponent();
  });

  describe('when initialized', () => {
    it('should have sorting options', () => {
      expect(findAllGlListboxItems()).toHaveLength(2);
    });

    it('should set the sorting option to `created_desc` by default', () => {
      expect(findGlCollapsibleListbox().props('selected')).toBe('created_desc');
    });

    describe('with a sortBy value', () => {
      beforeEach(() => {
        createComponent({
          sortBy: 'created_asc',
        });
      });

      it('should set the sorting option accordingly', () => {
        expect(findGlCollapsibleListbox().props('selected')).toBe('created_asc');
      });
    });
  });

  describe('when the user clicks on a option', () => {
    beforeEach(() => {
      createComponent();
      findGlCollapsibleListbox().vm.$emit('select', 'selected-option');
    });

    it('should emit the "selected" event with clicked option', () => {
      expect(wrapper.emitted().selected).toHaveLength(1);
      expect(wrapper.emitted().selected[0]).toEqual(['selected-option']);
    });
  });
});
