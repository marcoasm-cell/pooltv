module GameTypeSerializer
  module_function

  def call(gt)
    gt.slice(:id, :key, :name, :scoring_mode, :default_target, :break_rule, :rules_url).merge(built_in: gt.built_in?)
  end
end
