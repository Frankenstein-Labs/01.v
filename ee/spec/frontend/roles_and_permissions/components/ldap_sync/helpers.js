import { GlFormGroup, GlFormRadioGroup, GlFormTextarea } from '@gitlab/ui';
import { stubComponent, RENDER_ALL_SLOTS_TEMPLATE } from 'helpers/stub_component';

export const glFormGroupStub = stubComponent(GlFormGroup, {
  props: ['label', 'state', 'invalidFeedback'],
  template: RENDER_ALL_SLOTS_TEMPLATE,
});

export const glRadioGroupStub = stubComponent(GlFormRadioGroup, {
  props: ['checked', 'state', 'options', 'disabled'],
});

export const glFormTextareaStub = stubComponent(GlFormTextarea, {
  props: ['value', 'state', 'noResize', 'placeholder', 'rows', 'disabled'],
});
