import createRouter from 'ee/insights/insights_router';
import store from 'ee/insights/stores';

describe('insights router', () => {
  let router;

  beforeEach(async () => {
    router = createRouter('base');
    await router.push('/initial');
  });

  it(`sets the activeTab when route changed`, async () => {
    const route = 'route';

    jest.spyOn(store, 'dispatch').mockImplementation(() => {});

    await router.push(`/${route}`);

    expect(store.dispatch).toHaveBeenCalledWith('insights/setActiveTab', route);
  });
});
