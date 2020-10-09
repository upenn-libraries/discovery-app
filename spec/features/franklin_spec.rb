describe 'Franklin', type: :feature do
  describe 'landing page' do
    before do
      visit '/'
    end
    it 'renders' do
      expect(page).to have_text 'Franklin'
    end
  end
  describe 'bento', js: true do
    before do
      visit '/bento'
    end
    it 'renders the expected bento box divs' do
      expect(page).to have_css '#bento-results-catalog'
      expect(page).to have_css '#bento-results-summon'
      expect(page).to have_css '#bento-results-databases'
      expect(page).to have_css '#bento-results-colenda'
      expect(page).to have_css '#bento-results-expert'
    end
  end
  describe 'catalog', js: true do
    before do
      visit '/catalog'
    end
    it 'renders' do
      expect(page).to have_text 'Franklin Catalog'
    end
  end
end