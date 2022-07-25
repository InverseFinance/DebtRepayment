// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Vm} from "forge-std/Vm.sol";
import "forge-std/Test.sol";
import "src/DebtRepayer.sol";
import "src/IERC20.sol";

interface ComptrollerInterface {
    function _setTransferPaused(bool) external;
}

contract DebtRepayerTest is Test {

    DebtRepayer debtRepayer;

    uint decimals = 18;

    uint baseline = 10 ** decimals;

    address governance = 0x926dF14a23BE491164dCF93f4c468A50ef659D5B;
    
    address controller = address(0xb);

    address treasury = address(0xc);

    ComptrollerInterface comptroller = ComptrollerInterface(0x4dCf7407AE5C07f8681e1659f626E114A7667339);

    address anEthHolder = 0x3F7C10cBbb1EA1046a80B738b9Eaf3217410c7F6;
    address anBtcHolder = 0x63A9dF1C07BdeB97D634344827bf8f6140D93EC6;
    address anYfiHolder = 0x6fC34A8B9B4973b5E6b0B6a984Bb0bEcC9Ca2b29;

    address yfiHolder = 0xE174c389249b0E3a4eC84d2A5667Aa4920CB77DE;
    address wbtcHolder = 0x218B95BE3ed99141b0144Dba6cE88807c4AD7C09;
    address wethHolder = 0x06920C9fC643De77B99cB7670A944AD31eaAA260;

    IERC20 constant yfi = IERC20(0x0bc529c00C6401aEF6D220BE8C6Ea1667F6Ad93e);
    IERC20 constant wbtc = IERC20(0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599);
    IERC20 constant weth = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2); 

    address constant anEth = 0x697b4acAa24430F254224eB794d2a85ba1Fa1FB8;
    address constant anYfi = 0xde2af899040536884e062D3a334F2dD36F34b4a4;
    address constant anBtc = 0x17786f3813E6bA35343211bd8Fe18EC4de14F28b;

   

    function setUp() public{
        debtRepayer = new DebtRepayer(decimals, baseline / 2, baseline / 10, governance, controller, treasury);
        vm.startPrank(governance);
        comptroller._setTransferPaused(false);
        vm.stopPrank();
        /*
        vm.startPrank(anEthHolder);
        IERC20(anEth).approve(address(debtRepayer), type(uint).max);
        vm.stopPrank();
        vm.startPrank(anYfiHolder);
        IERC20(anYfi).approve(address(debtRepayer), type(uint).max);
        vm.stopPrank();
        vm.startPrank(anBtcHolder);
        IERC20(anBtc).approve(address(debtRepayer), type(uint).max);
        vm.stopPrank();
        */
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
        assertEq(debtRepayer.currentDiscount(anEth), debtRepayer.baseline(), "anEth discount not 0");
        assertEq(debtRepayer.currentDiscount(anYfi), debtRepayer.baseline(), "anYfi discount not 0");
        assertEq(debtRepayer.currentDiscount(anBtc), debtRepayer.baseline(), "anWbtc discount not 0");
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
        assertGt(amountIn, amountOut, "amountIn less than amountOut");
        assertEq(expectedOutput, amountOut, "expectedOutput not equal amountOut");
        assertEq(amountIn, amountInActual, "amountIn not equal amountInActual");
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
        emit log_uint(yfi.balanceOf(address(debtRepayer)));
        vm.stopPrank();
        vm.startPrank(anYfiHolder);
        IERC20(anYfi).transfer(address(debtRepayer), 10 ** 8);
        emit log_uint(IERC20(anYfi).balanceOf(address(debtRepayer)));

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

        //Act
        vm.startPrank(anYfiHolder);
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
        emit log_uint(remainingDebt);
        wbtc.transfer(address(debtRepayer), remainingDebt / 10);
        vm.stopPrank();
        //gibAnTokens(anBtcHolder, anBtc, 10 ** 10);

        //Act
        vm.startPrank(anBtcHolder);
        uint amountIn = IERC20(anBtc).balanceOf(anBtcHolder);
        uint amountInConverted = debtRepayer.convertToUnderlying(anBtc, amountIn);
        emit log_uint(amountInConverted);
        uint expectedOutput = remainingDebt / 10;
        emit log_uint(expectedOutput);
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

    function test_sweepTokens_when_CalledByGovernance() public {
        vm.startPrank(wbtcHolder);
        uint balance = wbtc.balanceOf(wbtcHolder);
        uint balanceTreasuryBefore = wbtc.balanceOf(treasury);
        wbtc.transfer(address(debtRepayer), balance);
        vm.stopPrank();

        vm.startPrank(governance);
        debtRepayer.sweepTokens(address(wbtc), balance);

        assertEq(wbtc.balanceOf(treasury), balance + balanceTreasuryBefore);
    }

    function test_sweepTokens_when_CalledByController() public {
        vm.startPrank(wbtcHolder);
        uint balance = wbtc.balanceOf(wbtcHolder);
        uint balanceTreasuryBefore = wbtc.balanceOf(treasury);
        wbtc.transfer(address(debtRepayer), balance);
        
        vm.stopPrank();
        vm.startPrank(controller);
        debtRepayer.sweepTokens(address(wbtc), balance);

        assertEq(wbtc.balanceOf(treasury), balance + balanceTreasuryBefore);
    }

    function testFail_sweepTokens_when_CalledByNonGovernance() public {
        vm.startPrank(wbtcHolder);
        uint balance = wbtc.balanceOf(wbtcHolder);
        wbtc.transfer(address(debtRepayer), balance);

        debtRepayer.sweepTokens(address(wbtc), balance);
    }

    function test_setMaxDiscount_success_when_CalledByGovernance() public {
        vm.startPrank(governance);
        uint oldMaxDiscount = debtRepayer.maxDiscount();
        
        debtRepayer.setMaxDiscount(oldMaxDiscount + 1);

        assertEq(oldMaxDiscount + 1, debtRepayer.maxDiscount());
    }

    function test_setMaxDiscount_success_when_CalledByController() public {
        vm.startPrank(controller);
        uint oldMaxDiscount = debtRepayer.maxDiscount();
        
        debtRepayer.setMaxDiscount(oldMaxDiscount + 1);

        assertEq(oldMaxDiscount + 1, debtRepayer.maxDiscount());
    }

    function testFail_setMaxDiscount_when_SetOverBaseline() public {
        vm.startPrank(governance);
        
        debtRepayer.setMaxDiscount(debtRepayer.baseline()+1);
    }

    function testFail_setMaxDiscount_when_CalledByNonGovernance() public {
        vm.startPrank(wbtcHolder);
        debtRepayer.setMaxDiscount(1);
    }

    function test_setZeroDiscountReserveThreshold_success_when_CalledByGovernance() public {
        vm.startPrank(governance);
        uint oldThreshold = debtRepayer.zeroDiscountReserveThreshold();
        
        debtRepayer.setZeroDiscountReserveThreshold(oldThreshold + 1);

        assertEq(oldThreshold + 1, debtRepayer.zeroDiscountReserveThreshold());
    }

    function test_setZeroDiscountReserveThreshold_success_when_CalledByController() public {
        vm.startPrank(controller);
        uint oldThreshold = debtRepayer.zeroDiscountReserveThreshold();
        
        debtRepayer.setZeroDiscountReserveThreshold(oldThreshold + 1);

        assertEq(oldThreshold + 1, debtRepayer.zeroDiscountReserveThreshold());
    }

    function testFail_setZeroDiscountReserveThreshold_when_SetOverBaseline() public {
        vm.startPrank(governance);
        
        debtRepayer.setZeroDiscountReserveThreshold(debtRepayer.baseline() + 1);
    }

    function testFail_setZeroDiscountReserveThreshold_when_CalledByNonGovernance() public {
        vm.startPrank(wbtcHolder);
        
        debtRepayer.setZeroDiscountReserveThreshold(1);
    }

    function test_setGovernance_success_when_CalledByGovernance() public {
        vm.startPrank(governance);

        assert(debtRepayer.governance() != treasury); 
        debtRepayer.setGovernance(treasury);
        assertEq(debtRepayer.governance(), treasury);
    }

    function testFail_setGovernance__when_CalledByNonGovernance() public {
        vm.startPrank(wbtcHolder);

        debtRepayer.setGovernance(treasury);
    }

    function test_setTreasury_success_when_CalledByTreasury() public {
        vm.startPrank(governance);

        assert(debtRepayer.treasury() != governance); 
        debtRepayer.setTreasury(governance);
        assertEq(debtRepayer.treasury(), governance);
    }

    function testFail_setTreasury__when_CalledByNonTreasury() public {
        vm.startPrank(wbtcHolder);

        debtRepayer.setTreasury(wbtcHolder);
    }

    function gibAnTokens(address _user, address _anToken, uint _amount) internal {
        bytes32 slot;
        assembly {
            mstore(0, _user)
            mstore(0x20, 0xE)
            slot := keccak256(0, 0x40)
        }

        vm.store(_anToken, slot, bytes32(_amount));
    }

}
