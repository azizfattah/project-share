module Utils
  def self.is_rtl_locale?
    [:ar].include?(I18n.locale)
  end
end
