// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Vm} from "forge-std/Vm.sol";
import "forge-std/Test.sol";
import "src/DebtRepayer.sol";
import "src/IERC20.sol";

contract DebtRepayerTest is Test {

    DebtRepayer debtRepayer;

    uint decimals = 18;

    uint baseline = 10 ** decimals;

    address owner = address(0xa);

    address treasury = address(0xb);

    address anEthHolder = 0x6fC34A8B9B4973b5E6b0B6a984Bb0bEcC9Ca2b29;
    address anBtcHolder = 0x63A9dF1C07BdeB97D634344827bf8f6140D93EC6;
    address anYfiHolder = 0x736DdE3E0F5c588dDC53ad7f0F65667C0Cca2801;

    address yfiHolder = 0xF977814e90dA44bFA03b6295A0616a897441aceC;
    address wbtcHolder = 0x8Fd589AA8bfA402156a6D1ad323FEC0ECee50D9D;
    address wethHolder = 0x6555e1CC97d3cbA6eAddebBCD7Ca51d75771e0B8;

    IERC20 constant yfi = IERC20(0x0bc529c00C6401aEF6D220BE8C6Ea1667F6Ad93e);
    IERC20 constant wbtc = IERC20(0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599);
    IERC20 constant weth = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2); 

    address constant anEth = 0x697b4acAa24430F254224eB794d2a85ba1Fa1FB8;
    address constant anYfi = 0xde2af899040536884e062D3a334F2dD36F34b4a4;
    address constant anBtc = 0x17786f3813E6bA35343211bd8Fe18EC4de14F28b;

   

    function setUp() public{
        debtRepayer = new DebtRepayer(decimals, baseline / 2, baseline / 10, owner, treasury);
    }

    function test_currentDiscount_isZero_when_reservesAreFull() public {
        //Arrange
        vm.startPrank(yfiHolder);
        yfi.transfer(address(debtRepayer), yfi.balanceOf(yfiHolder));
        vm.stopPrank();
        vm.startPrank(wbtcHolder);
        wbtc.transfer(address(debtRepayer), wbtc.balanceOf(wbtcHolder));
        vm.stopPrank();
        vm.startPrank(wethHolder);
        weth.transfer(address(debtRepayer), weth.balanceOf(wethHolder));

        //Assert
        assertEq(debtRepayer.currentDiscount(anEth), debtRepayer.baseline());
        assertEq(debtRepayer.currentDiscount(anYfi), debtRepayer.baseline());
        assertEq(debtRepayer.currentDiscount(anBtc), debtRepayer.baseline());
    }

    function test_currentDiscount_isMax_when_noReserves() public {

        assertEq(debtRepayer.currentDiscount(anEth), debtRepayer.maxDiscount());
        assertEq(debtRepayer.currentDiscount(anYfi), debtRepayer.maxDiscount());
        assertEq(debtRepayer.currentDiscount(anBtc), debtRepayer.maxDiscount());
    }

    function testFail_currentDiscount_reverts_when_wrongAnToken() public {
        debtRepayer.currentDiscount(address(0));
    }

    function test_remainingDebt_isWithinBallpark() public {
        uint remainingYfiDebt = debtRepayer.remainingDebt(anYfi);
        uint remainingBtcDebt = debtRepayer.remainingDebt(anBtc);
        uint remainingEthDebt = debtRepayer.remainingDebt(anEth);

        assertGt(50 * 10 ** 18, remainingYfiDebt);
        assertGt(100 * 10**8, remainingBtcDebt);
        assertGt(1600 * 10 ** 18, remainingEthDebt);
    }

    function test_amountOutYfi_isCorrectExchangeRate_when_FullYfiReserves() public {
        //Arrange
        vm.startPrank(yfiHolder);
        yfi.transfer(address(debtRepayer), yfi.balanceOf(yfiHolder));

        //Act
        uint amountIn = 10 ** 8;
        uint amountInConverted = debtRepayer.convertToUnderlying(anYfi, amountIn);
        uint expectedOutput = amountInConverted;
        (uint amountOut, uint amountInActual) = debtRepayer.amountOut(anYfi, yfi, amountIn);
        
        //Assert
        assertGt(amountOut, amountIn);
        assertEq(expectedOutput, amountOut);
        assertEq(amountIn, amountInActual);
    }

    function test_amountOutwBTC_isCorrectExchangeRate_when_FullwBTCReserves() public {
        //Arrange
        vm.startPrank(wbtcHolder);
        wbtc.transfer(address(debtRepayer), wbtc.balanceOf(wbtcHolder));

        //Act
        uint amountIn = 10 ** 8;
        uint amountInConverted = debtRepayer.convertToUnderlying(anBtc, amountIn);
        uint expectedOutput = amountInConverted;
        (uint amountOut, uint amountInActual) = debtRepayer.amountOut(anBtc, wbtc, amountIn);
        
        //Assert
        assertGt(amountIn, amountOut);
        assertEq(expectedOutput, amountOut);
        assertEq(amountIn, amountInActual);
    }

    function test_amountOutEth_isCorrectExchangeRate_when_FullEthReserves() public {
        //Arrange
        vm.startPrank(wethHolder);
        weth.transfer(address(debtRepayer), weth.balanceOf(wethHolder));

        //Act
        uint amountIn = 10 ** 8;
        uint amountInConverted = debtRepayer.convertToUnderlying(anEth, amountIn);
        uint expectedOutput = amountInConverted;
        (uint amountOut, uint amountInActual) = debtRepayer.amountOut(anEth, weth, amountIn);
        
        //Assert
        assertGt(amountOut, amountIn);
        assertEq(expectedOutput, amountOut);
        assertEq(amountIn, amountInActual);
    }

    function test_sellYfiDebt_isCorrect_when_FullYfiReserves() public {
        //Arrange
        vm.startPrank(yfiHolder);
        yfi.transfer(address(debtRepayer), yfi.balanceOf(yfiHolder));
        vm.stopPrank();
        vm.startPrank(anYfiHolder);

        //Act
        uint amountIn = 10 ** 8;
        uint amountInConverted = debtRepayer.convertToUnderlying(anYfi, amountIn);
        uint expectedOutput = amountInConverted;
        uint yfiBalanceBefore = yfi.balanceOf(anYfiHolder);
        uint anYfiBalanceBefore = IERC20(anYfi).balanceOf(anYfiHolder);
        IERC20(anYfi).approve(address(debtRepayer), amountIn);
        debtRepayer.sellDebt(anYfi, amountIn, expectedOutput);

        assertEq(expectedOutput, yfi.balanceOf(anYfiHolder) - yfiBalanceBefore);
        assertEq(amountIn, anYfiBalanceBefore - IERC20(anYfi).balanceOf(anYfiHolder));
    }

    function test_sellEthDebt_isCorrect_when_FullEthReserves() public {
        //Arrange
        vm.startPrank(wethHolder);
        weth.transfer(address(debtRepayer), weth.balanceOf(wethHolder));
        vm.stopPrank();
        vm.startPrank(anEthHolder);

        //Act
        uint amountIn = 10 ** 8;
        uint amountInConverted = debtRepayer.convertToUnderlying(anEth, amountIn);
        uint expectedOutput = amountInConverted;
        uint wethBalanceBefore = weth.balanceOf(anEthHolder);
        uint anEthBalanceBefore = IERC20(anEth).balanceOf(anEthHolder);
        IERC20(anEth).approve(address(debtRepayer), amountIn);
        debtRepayer.sellDebt(anEth, amountIn, expectedOutput);

        assertEq(expectedOutput, weth.balanceOf(anEthHolder) - wethBalanceBefore);
        assertEq(amountIn, anEthBalanceBefore - IERC20(anEth).balanceOf(anEthHolder));
    }

    function test_sellBtcDebt_isCorrect_when_FullBtcReserves() public {
        //Arrange
        vm.startPrank(wbtcHolder);
        wbtc.transfer(address(debtRepayer), wbtc.balanceOf(wbtcHolder));
        vm.stopPrank();
        vm.startPrank(anBtcHolder);

        //Act
        uint amountIn = 10 ** 8;
        uint amountInConverted = debtRepayer.convertToUnderlying(anBtc, amountIn);
        uint expectedOutput = amountInConverted;
        uint wbtcBalanceBefore = wbtc.balanceOf(anBtcHolder);
        uint anBtcBalanceBefore = IERC20(anBtc).balanceOf(anBtcHolder);
        IERC20(anBtc).approve(address(debtRepayer), amountIn);
        debtRepayer.sellDebt(anBtc, amountIn, expectedOutput);

        assertEq(expectedOutput, wbtc.balanceOf(anBtcHolder) - wbtcBalanceBefore);
        assertEq(amountIn, anBtcBalanceBefore - IERC20(anBtc).balanceOf(anBtcHolder));
    }

    function test_sellYfiDebt_discountIs75_when_HalfwayToThreshold() public {
        //Arrange
        vm.startPrank(yfiHolder);
        uint remainingDebt = debtRepayer.remainingDebt(anYfi);
        yfi.transfer(address(debtRepayer), remainingDebt*5/100);
        vm.stopPrank();
        vm.startPrank(anYfiHolder);

        //Act
        uint amountIn = 10 ** 8;
        uint amountInConverted = debtRepayer.convertToUnderlying(anYfi, amountIn);
        uint discountBefore = debtRepayer.currentDiscount(anYfi);
        uint expectedOutput = amountInConverted*debtRepayer.currentDiscount(anYfi)/debtRepayer.baseline();
        uint yfiBalanceBefore = yfi.balanceOf(anYfiHolder);
        uint anYfiBalanceBefore = IERC20(anYfi).balanceOf(anYfiHolder);
        IERC20(anYfi).approve(address(debtRepayer), amountIn);
        debtRepayer.sellDebt(anYfi, amountIn, expectedOutput);

        assertGt(discountBefore, debtRepayer.currentDiscount(anYfi));
        assertGt(amountInConverted, yfi.balanceOf(anYfiHolder) - yfiBalanceBefore);
        assertEq(expectedOutput, yfi.balanceOf(anYfiHolder) - yfiBalanceBefore);
        assertEq(amountIn, anYfiBalanceBefore - IERC20(anYfi).balanceOf(anYfiHolder));
    }

    function test_sellEthDebt_discountIs75_when_HalfwayToThreshold() public {
        //Arrange
        vm.startPrank(wethHolder);
        uint remainingDebt = debtRepayer.remainingDebt(anEth);
        weth.transfer(address(debtRepayer), remainingDebt*5/100);
        vm.stopPrank();
        vm.startPrank(anEthHolder);

        //Act
        uint amountIn = 10 ** 8;
        uint amountInConverted = debtRepayer.convertToUnderlying(anEth, amountIn);
        uint discountBefore = debtRepayer.currentDiscount(anEth);
        uint expectedOutput = amountInConverted*debtRepayer.currentDiscount(anEth)/debtRepayer.baseline();
        uint wethBalanceBefore = weth.balanceOf(anEthHolder);
        uint anEthBalanceBefore = IERC20(anEth).balanceOf(anEthHolder);
        IERC20(anEth).approve(address(debtRepayer), amountIn);
        debtRepayer.sellDebt(anEth, amountIn, expectedOutput);

        assertGt(discountBefore, debtRepayer.currentDiscount(anEth));
        assertGt(amountInConverted, weth.balanceOf(anEthHolder) - wethBalanceBefore);
        assertEq(expectedOutput, weth.balanceOf(anEthHolder) - wethBalanceBefore);
        assertEq(amountIn, anEthBalanceBefore - IERC20(anEth).balanceOf(anEthHolder));
    }

    function test_sellBtcDebt_discountIs75_when_HalfwayToThreshold() public {
        //Arrange
        vm.startPrank(wbtcHolder);
        uint remainingDebt = debtRepayer.remainingDebt(anBtc);
        wbtc.transfer(address(debtRepayer), remainingDebt*5/100);
        vm.stopPrank();
        vm.startPrank(anBtcHolder);

        //Act
        uint amountIn = 10 ** 8;
        uint amountInConverted = debtRepayer.convertToUnderlying(anBtc, amountIn);
        uint discountBefore = debtRepayer.currentDiscount(anBtc);
        uint expectedOutput = amountInConverted*debtRepayer.currentDiscount(anBtc)/debtRepayer.baseline();
        uint wbtcBalanceBefore = wbtc.balanceOf(anBtcHolder);
        uint anBtcBalanceBefore = IERC20(anBtc).balanceOf(anBtcHolder);
        IERC20(anBtc).approve(address(debtRepayer), amountIn);
        debtRepayer.sellDebt(anBtc, amountIn, expectedOutput);

        assertGt(discountBefore, debtRepayer.currentDiscount(anBtc));
        assertGt(amountInConverted, wbtc.balanceOf(anBtcHolder) - wbtcBalanceBefore);
        assertEq(expectedOutput, wbtc.balanceOf(anBtcHolder) - wbtcBalanceBefore);
        assertEq(amountIn, anBtcBalanceBefore - IERC20(anBtc).balanceOf(anBtcHolder));
    }

    function test_sellYfiDebt_isCorrect_when_SellMoreThanReserves() public {
        //Arrange
        vm.startPrank(yfiHolder);
        uint remainingDebt = debtRepayer.remainingDebt(anYfi);
        yfi.transfer(address(debtRepayer), remainingDebt / 10);
        vm.stopPrank();
        vm.startPrank(anYfiHolder);

        //Act
        uint amountIn = IERC20(anYfi).balanceOf(anYfiHolder);
        uint amountInConverted = debtRepayer.convertToUnderlying(anYfi, amountIn);
        uint expectedOutput = remainingDebt / 10;
        uint yfiBalanceBefore = yfi.balanceOf(anYfiHolder);
        uint anYfiBalanceBefore = IERC20(anYfi).balanceOf(anYfiHolder);
        IERC20(anYfi).approve(address(debtRepayer), amountIn);
        debtRepayer.sellDebt(anYfi, amountIn, expectedOutput);

        assertGt(amountInConverted, yfi.balanceOf(anYfiHolder) - yfiBalanceBefore);
        assertGt(amountIn, anYfiBalanceBefore - IERC20(anYfi).balanceOf(anYfiHolder));
        assertEq(expectedOutput, yfi.balanceOf(anYfiHolder) - yfiBalanceBefore);
    }

    function test_sellBtcDebt_isCorrect_when_SellMoreThanReserves() public {
        //Arrange
        vm.startPrank(wbtcHolder);
        uint remainingDebt = debtRepayer.remainingDebt(anBtc);
        wbtc.transfer(address(debtRepayer), remainingDebt / 10);
        vm.stopPrank();
        vm.startPrank(anBtcHolder);

        //Act
        uint amountIn = IERC20(anBtc).balanceOf(anBtcHolder);
        uint amountInConverted = debtRepayer.convertToUnderlying(anBtc, amountIn);
        uint expectedOutput = remainingDebt / 10;
        uint wbtcBalanceBefore = wbtc.balanceOf(anBtcHolder);
        uint anBtcBalanceBefore = IERC20(anBtc).balanceOf(anBtcHolder);
        IERC20(anBtc).approve(address(debtRepayer), amountIn);
        debtRepayer.sellDebt(anBtc, amountIn, expectedOutput);

        assertGt(amountInConverted, wbtc.balanceOf(anBtcHolder) - wbtcBalanceBefore);
        assertGt(amountIn, anBtcBalanceBefore - IERC20(anBtc).balanceOf(anBtcHolder));
        assertEq(expectedOutput, wbtc.balanceOf(anBtcHolder) - wbtcBalanceBefore);
    }

    function test_sellEthDebt_isCorrect_when_SellMoreThanReserves() public {
        //Arrange
        vm.startPrank(wethHolder);
        uint remainingDebt = debtRepayer.remainingDebt(anEth);
        weth.transfer(address(debtRepayer), remainingDebt / 10);
        vm.stopPrank();
        vm.startPrank(anEthHolder);

        //Act
        uint amountIn = IERC20(anEth).balanceOf(anEthHolder);
        uint amountInConverted = debtRepayer.convertToUnderlying(anEth, amountIn);
        uint expectedOutput = remainingDebt / 10;
        uint wethBalanceBefore = weth.balanceOf(anEthHolder);
        uint anEthBalanceBefore = IERC20(anEth).balanceOf(anEthHolder);
        IERC20(anEth).approve(address(debtRepayer), amountIn);
        debtRepayer.sellDebt(anEth, amountIn, expectedOutput);

        assertGt(amountInConverted, weth.balanceOf(anEthHolder) - wethBalanceBefore);
        assertGt(amountIn, anEthBalanceBefore - IERC20(anEth).balanceOf(anEthHolder));
        assertEq(expectedOutput, weth.balanceOf(anEthHolder) - wethBalanceBefore);
    }

    // ************************
    // * ACCESS CONTROL TESTS *
    // ************************

    function test_sweepTokens_when_CalledByOwner() public {
        vm.startPrank(wbtcHolder);
        uint balance = wbtc.balanceOf(wbtcHolder);
        uint balanceOwnerBefore = wbtc.balanceOf(owner);
        wbtc.transfer(address(debtRepayer), balance);
        
        vm.stopPrank();
        vm.startPrank(owner);
        debtRepayer.sweepTokens(address(wbtc), balance);

        assertEq(wbtc.balanceOf(owner), balance + balanceOwnerBefore);
    }

    function testFail_sweepTokens_when_CalledByNonOwner() public {
        vm.startPrank(wbtcHolder);
        uint balance = wbtc.balanceOf(wbtcHolder);
        wbtc.transfer(address(debtRepayer), balance);

        debtRepayer.sweepTokens(address(wbtc), balance);
    }

    function test_setMaxDiscount_success_when_CalledByOwner() public {
        vm.startPrank(owner);
        uint oldMaxDiscount = debtRepayer.maxDiscount();
        
        debtRepayer.setMaxDiscount(oldMaxDiscount + 1);

        assertEq(oldMaxDiscount + 1, debtRepayer.maxDiscount());
    }

    function testFail_setMaxDiscount_when_SetOverBaseline() public {
        vm.startPrank(owner);
        
        debtRepayer.setMaxDiscount(debtRepayer.baseline()+1);
    }

    function testFail_setMaxDiscount_when_CalledByNonOwner() public {
        vm.startPrank(wbtcHolder);
        debtRepayer.setMaxDiscount(1);
    }

    function test_setZeroDiscountReserveThreshold_success_when_CalledByOwner() public {
        vm.startPrank(owner);
        uint oldThreshold = debtRepayer.zeroDiscountReserveThreshold();
        
        debtRepayer.setZeroDiscountReserveThreshold(oldThreshold + 1);

        assertEq(oldThreshold + 1, debtRepayer.zeroDiscountReserveThreshold());
    }

    function testFail_setZeroDiscountReserveThreshold_when_SetOverBaseline() public {
        vm.startPrank(owner);
        
        debtRepayer.setZeroDiscountReserveThreshold(debtRepayer.baseline() + 1);
    }

    function testFail_setZeroDiscountReserveThreshold_when_CalledByNonOwner() public {
        vm.startPrank(wbtcHolder);
        
        debtRepayer.setZeroDiscountReserveThreshold(1);
    }

    function test_setOwner_success_when_CalledByOwner() public {
        vm.startPrank(owner);

        assert(debtRepayer.owner() != treasury); 
        debtRepayer.setOwner(treasury);
        assertEq(debtRepayer.owner(), treasury);
    }

    function testFail_setOwner__when_CalledByNonOwner() public {
        vm.startPrank(wbtcHolder);

        debtRepayer.setOwner(treasury);
    }

    function test_setTreasury_success_when_CalledByTreasury() public {
        vm.startPrank(owner);

        assert(debtRepayer.treasury() != owner); 
        debtRepayer.setTreasury(owner);
        assertEq(debtRepayer.treasury(), owner);
    }

    function testFail_setTreasury__when_CalledByNonTreasury() public {
        vm.startPrank(wbtcHolder);

        debtRepayer.setTreasury(wbtcHolder);
    }
}
