local rpc = require "sg.cody.rpc"
local types = require "sg.types"
local cody_subscription_status = types.cody_subscription_status
local cody_subscription_plan = types.cody_subscription_plan

rpc.request("graphql/getCurrentUserCodySubscription", {}, function(_, subscription)
  ---@type cody.CurrentUserCodySubscription
  subscription = subscription

  print("subscription:", vim.inspect { data = subscription })
  if
    subscription.plan == cody_subscription_plan.PRO
    and subscription.status == cody_subscription_status.PENDING
  then
    rpc.request(
      "featureFlags/getFeatureFlag",
      { flagName = "use-ssc-for-cody-subscription" },
      function(_, data)
        print("feature:", data)
      end
    )
  end
end)

-- rpc.request(
--   "featureFlags/getFeatureFlag",
--   { flagName = "cody-pro-trial-ended" },
--   function(err, data)
--     print(vim.inspect { err = err, data = data })
--   end
-- )
--

vim.notify_once [[
[sg-cody] Your Cody Pro Trial is ending soon. 

Setup your payment information to continue using Cody Pro, you won't be charged until February 15.

See :help cody.pro-trial-ending]]
