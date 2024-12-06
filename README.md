What this project does:

1. Users use their account address and select the supported ways to make payments and the supported chains to make payments.
2. Our contract will monitor the user's account after some time and check if the user has enough balance to make the payment.
3. If the user has enough balance, the contract will take some amount of the user's balance and send it to the recipient's address.
4. If the user does not have enough balance, the contract will rather check the second chain where user has enough balance and send the payment from that chain.
5. If the user does not have enough balance in any of the chains, the contract will then notify the user about the insufficient balance.

This is like a subscription service where the user can select the supported chains and supported ways to make payments and the contract will automatically make the payment from the user's account to the recipient's account.
