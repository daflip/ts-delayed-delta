ThinkingSphinx::Index.define :book, :with => :active_record, :delta => ThinkingSphinx::Deltas::DelayedDelta do
  indexes title, author
end
