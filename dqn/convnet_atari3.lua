--[[
Copyright (c) 2014 Google Inc.

See LICENSE file for full terms of limited license.
]]


require 'convnet'

print("QQQQQQQQQQQQQQ")
return function(args)
  
print("SSSSSSSSSS")
    args.n_units        = {32, 64, 64}
    args.filter_size    = {8, 4, 3}
    args.filter_stride  = {4, 2, 1}
    args.n_hid          = {512}
    args.nl             = nn.Rectifier
  
print("AAAAAAAAAAA")
    return create_network(args), args
end

