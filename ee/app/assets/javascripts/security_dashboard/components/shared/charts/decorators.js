import { createPinia, setActivePinia } from 'pinia';

export const withPinia = () => {
  setActivePinia(createPinia());
  return {
    template: '<story />',
  };
};
