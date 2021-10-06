//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

interface IROFI {
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    
    function transfer(address recipient, uint256 amount) external returns (bool);
    
    function balanceOf(address account) external view returns (uint256);
    
    function approve(address spender, uint256 amount) external returns (bool);
}

interface IUniswapV2Factory {
    event PairCreated(address indexed token0, address indexed token1, address pair, uint);

    function feeTo() external view returns (address);
    function feeToSetter() external view returns (address);

    function getPair(address tokenA, address tokenB) external view returns (address pair);
    function allPairs(uint) external view returns (address pair);
    function allPairsLength() external view returns (uint);

    function createPair(address tokenA, address tokenB) external returns (address pair);

    function setFeeTo(address) external;
    function setFeeToSetter(address) external;
}

interface IUniswapV2Router01 {
    function factory() external pure returns (address);
    function WETH() external pure returns (address);

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB, uint liquidity);
    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB);
    function removeLiquidityETH(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external returns (uint amountToken, uint amountETH);
    function removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountA, uint amountB);
    function removeLiquidityETHWithPermit(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountToken, uint amountETH);
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    function swapTokensForExactTokens(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    function swapExactETHForTokens(uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        payable
        returns (uint[] memory amounts);
    function swapTokensForExactETH(uint amountOut, uint amountInMax, address[] calldata path, address to, uint deadline)
        external
        returns (uint[] memory amounts);
    function swapExactTokensForETH(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        returns (uint[] memory amounts);
    function swapETHForExactTokens(uint amountOut, address[] calldata path, address to, uint deadline)
        external
        payable
        returns (uint[] memory amounts);

    function quote(uint amountA, uint reserveA, uint reserveB) external pure returns (uint amountB);
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) external pure returns (uint amountOut);
    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut) external pure returns (uint amountIn);
    function getAmountsOut(uint amountIn, address[] calldata path) external view returns (uint[] memory amounts);
    function getAmountsIn(uint amountOut, address[] calldata path) external view returns (uint[] memory amounts);
}

interface IUniswapV2Router02 is IUniswapV2Router01 {
    function removeLiquidityETHSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external returns (uint amountETH);
    function removeLiquidityETHWithPermitSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountETH);

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable;
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
}

contract PayRofi is Ownable {
    using SafeMath for uint256;
    
    address public dev_team_address;
    
    address public advisor_address;
    
    address public dev_mkt_address;
    
    uint8 public burn_percentage = 60;
    
    uint8 public dev_team_percentage = 18;
    
    uint8 public advisor_percentage = 2;
    
    uint8 public dev_mkt_percentage = 10;
    
    uint8 public add_liquidity_percentage = 10;
    
    uint256 public _liquidityReservoir;
    
    IUniswapV2Router02 public immutable uniswapV2Router;
    
    address public immutable uniswapV2Pair;
    
    bool inSwapAndLiquify;
    
    address public _foundation;
    
    IROFI private rofi;
    
    event SwapAndLiquify(
        uint256 tokensSwapped,
        uint256 ethReceived,
        uint256 tokensIntoLiqudity
    );
    
    modifier lockTheSwap {
        inSwapAndLiquify = true;
        _;
        inSwapAndLiquify = false;
    }
    
    constructor(address _rofi) {
        rofi = IROFI(_rofi);
        
        IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(0x10ED43C718714eb63d5aA57B78B54704E256024E); // Pancakeswap mainnet
        
         // Create a uniswap pair for this new token
        uniswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory()).createPair(address(this), _uniswapV2Router.WETH());

        // set the rest of the contract variables
        uniswapV2Router = _uniswapV2Router;
        
        _liquidityReservoir = 50000 * 10 ** 18;
        
        _foundation = address(msg.sender);
    }
    
    // to recieve ETH from uniswapV2Router when swaping
    receive() external payable {}
    
    function payRofi(uint256 _amount) external onlyOwner {
        uint256 amount = _amount.div(100);
        rofi.transfer(address(0x000000000000000000000000000000000000dEaD), amount.mul(burn_percentage));
        rofi.transfer(dev_team_address, amount.mul(dev_team_percentage));
        rofi.transfer(advisor_address, amount.mul(advisor_percentage));
        rofi.transfer(dev_mkt_address, amount.mul(dev_mkt_percentage));
        
        if (add_liquidity_percentage > 0) {
            addLiquidity(amount.mul(add_liquidity_percentage));
        }
    }
    
    function addLiquidity(uint256 _amount) internal {
        rofi.transfer(address(this), _amount);
        
        uint256 contractTokenBalance = rofi.balanceOf(address(this));
        
        if (contractTokenBalance >= _liquidityReservoir && !inSwapAndLiquify) {
            swapAndLiquify(contractTokenBalance);
        }
    }
    
    function swapAndLiquify(uint256 contractTokenBalance) private lockTheSwap {
        // split the contract balance into halves
        uint256 half = contractTokenBalance.div(2);
        uint256 otherHalf = contractTokenBalance.sub(half);

        // capture the contract's current ETH balance.
        // this is so that we can capture exactly the amount of ETH that the
        // swap creates, and not make the liquidity event include any ETH that
        // has been manually sent to the contract
        uint256 initialBalance = rofi.balanceOf(address(this));

        // swap tokens for ETH
        swapTokensForEth(half); // <- this breaks the ETH -> HATE swap when swap+liquify is triggered

        // how much ETH did we just swap into?
        uint256 newBalance = rofi.balanceOf(address(this)).sub(initialBalance);

        // add liquidity to uniswap
        addLiquidityToUniswap(otherHalf, newBalance);
        
        emit SwapAndLiquify(half, newBalance, otherHalf);
    }
    
    function swapTokensForEth(uint256 tokenAmount) private {
        // generate the uniswap pair path of token -> weth
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();

        rofi.approve(address(uniswapV2Router), tokenAmount);

        // make the swap
        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0, // accept any amount of ETH
            path,
            address(this),
            block.timestamp
        );
    }

    function addLiquidityToUniswap(uint256 tokenAmount, uint256 ethAmount) private {
        // approve token transfer to cover all possible scenarios
        rofi.approve(address(uniswapV2Router), tokenAmount);

        // add the liquidity
        uniswapV2Router.addLiquidityETH{value: ethAmount}(
            address(this),
            tokenAmount,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            _foundation,
            block.timestamp
        );
    }
    
    function updateRofiAddress(address _newAddress) external onlyOwner {
        rofi = IROFI(_newAddress);
    }
    
    function updateDevTeamAddress(address _newAddress) external onlyOwner {
        dev_team_address = _newAddress;
    }
    
    function updateAdvisorAddress(address _newAddress) external onlyOwner {
        advisor_address = _newAddress;
    }
    
    function updateDevMktAddress(address _newAddress) external onlyOwner {
        dev_mkt_address = _newAddress;
    }
    
    function setLiquidityReservoir(uint256 liquidityReservoir) external onlyOwner() {
        _liquidityReservoir = liquidityReservoir;
    }
    
    function setFoundation(address foundation) external {
        require(msg.sender == _foundation, "Only existing Foundation could change it address");
        _foundation = foundation;
    }
    
    function setBurnPercentage(uint8 _percentage) external onlyOwner {
        burn_percentage = _percentage;    
    }
    
    function setDevTeamPercentage(uint8 _percentage) external onlyOwner {
        dev_team_percentage = _percentage;    
    }
    
    function setAdvisorPercentage(uint8 _percentage) external onlyOwner {
        advisor_percentage = _percentage;    
    }
    
    function setDevMktPercentage(uint8 _percentage) external onlyOwner {
        dev_mkt_percentage = _percentage;    
    }
    
    function setAddLiquidityPercentage(uint8 _percentage) external onlyOwner {
        add_liquidity_percentage = _percentage;    
    }
    
}