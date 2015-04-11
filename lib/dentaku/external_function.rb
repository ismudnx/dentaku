class ExternalFunction < Struct.new(:name, :type, :signature, :body)
  def initialize(*)
    super
    self.name = self.name.to_s
  end

  def tokens
    signature.map { |t| [t, :comma] }.flatten[0...-1]
  end
end
