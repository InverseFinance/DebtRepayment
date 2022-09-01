decimals=4;
maxDiscount=5500;
zeroDiscountReserveThreshold=1500;
gov=0x926dF14a23BE491164dCF93f4c468A50ef659D5B;
controller=0x926dF14a23BE491164dCF93f4c468A50ef659D5B;
treasury=0x9D5Df30F475CEA915b1ed4C0CCa59255C897b61B;
forge create --rpc-url $1 \
    --constructor-args $decimals $maxDiscount $zeroDiscountReserveThreshold $gov $controller $treasury \
    --private-key $3 src/DebtRepayer.sol:DebtRepayer \
    --etherscan-api-key $2 \
    --verify

