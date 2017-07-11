begin
  require 'pry-byebug'
rescue LoadError
end

require 'state_machines-activemodel'
require 'state_machines-activemodel-observers'
require 'minitest/autorun'
require 'minitest/reporters'
