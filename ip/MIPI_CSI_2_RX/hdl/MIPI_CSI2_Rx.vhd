----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 04/14/2016 01:57:26 PM
-- Design Name: 
-- Module Name: CSI2 - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity MIPI_CSI2_Rx is
   Generic (
      kTargetDT : string := "RAW10";
      --PPI
      kLaneCount : natural range 1 to 4 := 2; --[1,2,4]
      --Video Format
      C_M_AXIS_COMPONENT_WIDTH : natural := 10; -- [8,10]
      C_M_AXIS_TDATA_WIDTH : natural := 40;
      C_M_MAX_SAMPLES_PER_CLOCK : natural := 4
   );
   Port ( 
      --PPI
      RxByteClkHS : in STD_LOGIC;
      aClkStopstate : in std_logic;
      aRxClkActiveHS : in std_logic;
      
      rbRxDataHS : in STD_LOGIC_VECTOR (8 * kLaneCount - 1 downto 0);
      rbRxSyncHS : in STD_LOGIC_VECTOR (kLaneCount - 1 downto 0);
      rbRxValidHS : in STD_LOGIC_VECTOR (kLaneCount - 1 downto 0);
      rbRxActiveHS : in STD_LOGIC_VECTOR (kLaneCount - 1 downto 0);
      aDEnable : out STD_LOGIC_VECTOR (kLaneCount - 1 downto 0);      
      aClkEnable : out STD_LOGIC;
      
      --axi stream signals
      m_axis_video_tdata    : out std_logic_vector(C_M_AXIS_TDATA_WIDTH-1 downto 0);
      m_axis_video_tvalid   : out std_logic;
      m_axis_video_tready   : in std_logic;
      m_axis_video_tlast    : out std_logic;
      m_axis_video_tuser    : out std_logic_vector(0 downto 0);
      
      video_aresetn        : in std_logic;
      video_aclk           : in std_logic;
      vEnable              : in std_logic  --TODO proper buffer flushing on disable, perhaps waiting on active transfer to end
    );
end MIPI_CSI2_Rx;

architecture Behavioral of MIPI_CSI2_Rx is
   component LM is
      Generic(
         kMaxLaneCount : natural := 4;
         --PPI
         kLaneCount : natural range 1 to 4 := 2 --[1,2,4]
      );
      Port (
         RxByteClkHS : in STD_LOGIC;
         RxDataHS : in  STD_LOGIC_VECTOR (8 * kLaneCount - 1 downto 0);
         RxSyncHS : in  STD_LOGIC_VECTOR (kLaneCount - 1 downto 0);
         RxValidHS : in  STD_LOGIC_VECTOR (kLaneCount - 1 downto 0);
         RxActiveHS : in  STD_LOGIC_VECTOR (kLaneCount - 1 downto 0);
          
         --Master AXI-Stream
         rbMAxisTdata : out std_logic_vector(8 * kMaxLaneCount - 1 downto 0);
         rbMAxisTkeep : out std_logic_vector(kMaxLaneCount - 1 downto 0);
         rbMAxisTvalid : out std_logic;
         rbMAxisTready : in std_logic;
         rbMAxisTlast : out std_logic;
         
         rbErrSkew : out std_logic;
         rbErrOvf : out std_logic;
         
         rbEn  : in std_logic;
         rbRst : in std_logic
      );
   end component LM;
   component LLP is
      Generic(
         kMaxLaneCount : natural := 4;
         --PPI
         kLaneCount : natural range 1 to 4 := 2; --[1,2,4];
         kTargetDT : string := "RAW10"
      );
      Port (
         SAxisClk : in STD_LOGIC;
         --Slave AXI-Stream
         sAxisTdata : in std_logic_vector(8 * kMaxLaneCount - 1 downto 0);
         sAxisTkeep : in std_logic_vector(kMaxLaneCount - 1 downto 0);
         sAxisTvalid : in std_logic;
         sAxisTready : out std_logic;
         sAxisTlast : in std_logic;
         
         MAxisClk : in std_logic;
         --Master AXI-Stream
         mAxisTdata : out std_logic_vector(40 - 1 downto 0);
         mAxisTvalid : out std_logic;
         mAxisTready : in std_logic;
         mAxisTlast : out std_logic;
         mAxisTuser : out std_logic_vector(0 downto 0);
               
         sOverflow : out std_logic;
         aRst : in std_logic -- global asynchronous reset; synchronized internally to both clock domains
      );
   end component;
   constant kMaxLaneCount : natural := 4;
   
   signal rbLMAxisTdata : std_logic_vector(8 * kMaxLaneCount - 1 downto 0);
   signal rbLMAxisTkeep : std_logic_vector(kMaxLaneCount - 1 downto 0);
   signal rbLMAxisTvalid, rbLMAxisTlast : std_logic;
   signal rbLMErrOvf, rbLMErrSkew : std_logic;
   signal rbLLPAxisTready : std_logic;
   signal rbRst_n, rbEn : std_logic;
   signal vTready, vRst : std_logic;
begin

-- Synchronize video_aresetn into the RxByteClkHS domain
SyncReset: entity work.ResetBridge
   generic map (
      kPolarity => '0')
   port map (
      aRst => video_aresetn,
      OutClk => RxByteClkHS,
      oRst => rbRst_n);

-- Synchronize vEnable into the RxByteClkHS domain
SyncAsyncEnable: entity work.SyncAsync
   generic map (
      kResetTo => '0',
      kStages => 2, --use double FF synchronizer
      kResetPolarity => '0') 
   port map (
      aReset => rbRst_n,
      aIn => vEnable,
      OutClk => RxByteClkHS,
      oOut => rbEn);

GlitchFree_vRst: process(video_aclk)
begin
   if Rising_Edge(video_aclk) then
      vRst <= not video_aresetn;
   end if;
end process;

PPI_Clock_Enable: process(video_aclk)
begin
   if Rising_Edge(video_aclk) then
      aClkEnable <= vEnable and video_aresetn;
   end if;
end process;

PPI_Data_Enable: process(video_aclk)
begin
   if Rising_Edge(video_aclk) then
      if (video_aresetn = '0') then
         aDEnable    <= (others => '0');
      else
         if (vEnable = '0') then
            aDEnable    <= (others => '0');
         elsif (vTready = '1') then --LLP buffer should be ready to receive data before enabling the PHY
            aDEnable    <= (others => '1');
         end if;
      end if;
   end if;
end process;
            
SyncAsyncTready: entity work.SyncAsync
   generic map (
      kResetTo => '0',
      kStages => 2, --use double FF synchronizer
      kResetPolarity => '0') 
   port map (
      aReset => video_aresetn,
      aIn => rbLLPAxisTready,
      OutClk => video_aclk,
      oOut => vTready);

-- Lane merger compacts the CSI-2 lane into a wide AXI-Stream bus
-- Both the input and output interfaces are synchronous to RxByteClkHS
-- and it does not buffer data
LM_inst: LM
   Generic Map( 
      kMaxLaneCount  => kMaxLaneCount,
      kLaneCount     => kLaneCount
   )
   Port Map( 
      RxByteClkHS    => RxByteClkHS,
      RxDataHS       => rbRxDataHS,
      RxSyncHS       => rbRxSyncHS,
      RxValidHS      => rbRxValidHS,
      RxActiveHS     => rbRxActiveHS,
      
      rbMAxisTdata   => rbLMAxisTdata,
      rbMAxisTkeep   => rbLMAxisTkeep,
      rbMAxisTvalid  => rbLMAxisTvalid,
      rbMAxisTready  => rbLLPAxisTready,
      rbMAxisTlast   => rbLMAxisTlast,
      
      rbErrSkew      => rbLMErrSkew,
      rbErrOvf       => rbLMErrOvf,
      
      rbEn           => rbEn,
      rbRst          => not rbRst_n
   );

-- Link-level protocol decodes short and long packets into frames, lines
-- and pixels. It synchronizes data from the MIPI clock domain (RxByteClkHS)
-- to the video pipeline domain video_aclk. It does error detection
-- and correction, filters data according to the target data type and
-- formats it according to UG934, ready to source a video processing
-- pipeline.
LLP_inst: LLP
   Generic map (
      kMaxLaneCount => kMaxLaneCount,
      --PPI
      kLaneCount => kLaneCount, --[1,2,4]
      kTargetDT => kTargetDT
   )
   Port map (
      SAxisClk => RxByteClkHS,
      --Slave AXI-Stream
      sAxisTdata => rbLMAxisTdata, 
      sAxisTkeep => rbLMAxisTkeep,
      sAxisTvalid => rbLMAxisTvalid,
      sAxisTready => rbLLPAxisTready,
      sAxisTlast => rbLMAxisTlast,
      
      MAxisClk => video_aclk,
      --Master AXI-Stream
      mAxisTdata => m_axis_video_tdata,
      mAxisTvalid => m_axis_video_tvalid,
      mAxisTready => m_axis_video_tready,
      mAxisTlast => m_axis_video_tlast,
      mAxisTuser => m_axis_video_tuser,
      
      aRst => vRst,
            
      sOverflow => open
   );
end Behavioral;
