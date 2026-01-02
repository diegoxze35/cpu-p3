library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.instruction_set.all;
use work.registers.all;

entity cpu_top is port(
	clk     : in  std_logic;
	reset   : in  std_logic;
	sw      : in  std_logic_vector(1 downto 0);
	leds    : out std_logic_vector(4 downto 0);
	segments: out std_logic_vector(6 downto 0); -- a,b,c,d,e,f,g
	digits  : out std_logic_vector(3 downto 0)  -- Dig 1, 2, 3,
);

end entity cpu_top;

architecture Behavioral of cpu_top is
	
	signal regs         : REGISTERS := (others => (others => '0'));
	signal reg_addr     : integer range 0 to 4;
	signal data_to_load : std_logic_vector(15 downto 0);

	type STATE is (FETCH, DECODE, EXECUTE);
	signal current_state: STATE := FETCH;
	
	-- Registros de proposito especifico
	signal PC: integer range 0 to 255 := 0;
	signal IR: std_logic_vector(15 downto 0);
	
	-- Señales ALU
   signal alu_op  				  : std_logic_vector(1 downto 0);
	signal alu_inA 				  : std_logic_vector(15 downto 0);
   signal alu_inB 				  : std_logic_vector(15 downto 0);
   signal alu_res 				  : std_logic_vector(15 downto 0);
	signal nc, nz, no, ns        : std_logic;
		
	signal rom_addr    : integer range 0 to 255 := PC;
	signal addr_operand: integer range 0 to 255;
	signal rom_data    : std_logic_vector(15 downto 0);
	
	-- Señales display
	signal display_reset: std_logic := '0';
	signal display_number: std_logic_vector(15 downto 0) := x"0000";
	
	-- Señales comparador
	signal cmp_a, cmp_b  : std_logic_vector(15 downto 0) := x"0000";
	signal G, E, L      : std_logic;
	
	-- Señales para contador
	signal counter_delay: integer range 0 to integer'high := 0;
	signal target_delay : integer range 0 to integer'high := 0;

begin
	
	U_ROM: entity work.PROGRAM_MEMORY port map(
		addr => rom_addr,
		dout => rom_data
	);
	
	U_ALU: entity work.ARITH_UNIT 
	generic map(LEN => 16)
	port map(
		A        => alu_inA,
		B        => alu_inB,
		OP_SEL   => alu_op,
		F_ARIT   => alu_res,
		C_OUT    => nc,
		OVF_OUT  => no,
		SIGN_OUT => ns,
		Z_OUT    => nz
	);
	
	U_CMP: entity work.COMPARATOR
	port map(
		A => cmp_a,
		B => cmp_b,
		G => G,
		E => E,
		L => L
	);
	
	U_DISPLAY: entity work.DISPLAY_CONTROLLER
   port map(
        clk      => clk,
        reset    => display_reset,
        data_in  => display_number,
        segments => segments,
        anodes   => digits
   );
	
	process(clk, reset)
		variable op_code      : std_logic_vector(7 downto 0);
		variable operand      : std_logic_vector(7 downto 0);
		variable led          : integer range 0 to 4;
		constant CLK_FREQ     : integer := 50000000;
	begin
		if not reset then -- Reset activo bajo
			current_state <= FETCH;
			case sw is
				when "00"   => PC <= 0;   -- Ec 1
				when "01"   => PC <= 21;  -- Ec 2
				when "10"   => PC <= 44; -- Ec 3
				when others => PC <= 196; 
			end case;
			leds <= (others => '0');
			display_reset <= '0';
		elsif rising_edge(clk) then
			case current_state is
				when FETCH =>
						IR <= rom_data;
						PC <= PC + 1;
						current_state <= DECODE;
				when DECODE => 
					op_code := IR(15 downto 8);
					operand := IR(7 downto 0);
					case op_code is
						when LDA_MEM =>
							reg_addr <= ACC;
							addr_operand <= to_integer(unsigned(operand));
							current_state <= EXECUTE;
						when MOV_R =>
							reg_addr <= to_integer(unsigned(operand));
							data_to_load <= regs(ACC);
							current_state <= EXECUTE;
						when MOV_A =>
							reg_addr <= ACC;
							data_to_load <= regs(to_integer(unsigned(operand)));
							current_state <= EXECUTE;
						when LDA_IMM =>
							reg_addr <= ACC;
							data_to_load <= std_logic_vector(resize(signed(/*IR(7 downto 0)*/operand), 16));
							current_state <= EXECUTE;
						when ADD =>
							reg_addr <= ACC;
							alu_op <= "00";
							alu_inA <= regs(ACC);
							alu_inB <= regs(to_integer(unsigned(operand)));
							current_state <= EXECUTE;
						when SUBS =>							
							reg_addr <= ACC;
							alu_op <= "01";
							alu_inA <= regs(ACC);
							alu_inB <= regs(to_integer(unsigned(operand)));
							current_state <= EXECUTE;
						when MULT =>
							reg_addr <= ACC;
							alu_op <= "10";
							alu_inA <= regs(ACC);
							alu_inB <= regs(to_integer(unsigned(operand)));
							current_state <= EXECUTE;
						when DIV =>
							reg_addr <= ACC;
							alu_op <= "11";
							alu_inA <= regs(ACC);
							alu_inB <= regs(to_integer(unsigned(operand)));
							current_state <= EXECUTE;
						when ADD_IMM =>
							reg_addr <= ACC;
							alu_op <= "00";
							alu_inA <= regs(ACC);
							alu_inB <= std_logic_vector(resize(signed(/*IR(7 downto 0)*/operand), 16));
							current_state <= EXECUTE;
						when SUB_IMM =>
							reg_addr <= ACC;
							alu_op <= "01";
							alu_inA <= regs(ACC);
							alu_inB <= std_logic_vector(resize(signed(/*IR(7 downto 0)*/operand), 16));
							current_state <= EXECUTE;
						when CMP_IMM =>
							cmp_a <= regs(ACC);
							cmp_b <= std_logic_vector(resize(signed(/*IR(7 downto 0)*/operand), 16));
							current_state <= FETCH;
						when CMP_REG =>
							/**/
							cmp_a <= regs(ACC);
							cmp_b <= regs(to_integer(unsigned(operand)));
							current_state <= FETCH;
						when JMP =>
							PC <= to_integer(unsigned(operand));
							current_state <= FETCH;
						when BCE =>
							if E then
								PC <= to_integer(unsigned(operand));
							end if;
							current_state <= FETCH;
						when BCG =>
							if G then
								PC <= to_integer(unsigned(operand));
							end if;
							current_state <= FETCH;
						when BCL =>
							if L then
								PC <= to_integer(unsigned(operand));
							end if;
							current_state <= FETCH;
						when BCGE =>
							if G or E then
								PC <= to_integer(unsigned(operand));
							end if;
							current_state <= FETCH;
						when BCLE =>
							if L or E then
								PC <= to_integer(unsigned(operand));
							end if;
							current_state <= FETCH;
						when BNZ =>
						   if nz then -- nz = 1 porque esta negada y la instrucción es salto si no
								PC <= to_integer(unsigned(operand));
							end if;
							current_state <= FETCH;
						when BNS =>
							if ns then
								PC <= to_integer(unsigned(operand));
							end if;
							current_state <= FETCH;
						when BNC =>
							if nc then
								PC <= to_integer(unsigned(operand));
							end if;
							current_state <= FETCH;
						when BNV =>
							if no then
								PC <= to_integer(unsigned(operand));
							end if;
							current_state <= FETCH;
						when SLEEP =>
							target_delay <= CLK_FREQ * to_integer(unsigned(operand));
							current_state <= EXECUTE;
						when ON_LED =>
							led := to_integer(unsigned(operand));
							leds(led) <= '1';
							current_state <= FETCH;
						when OFF_LED =>
							led := to_integer(unsigned(operand));
							leds(led) <= '0';
							current_state <= FETCH;
						when ON_LEDR =>
							led := to_integer(unsigned(regs(to_integer(unsigned(operand)))));
							leds(led) <= '1';
							current_state <= FETCH;
						when DISPLAY =>
							display_reset <= '1';
							display_number <= regs(ACC);
							current_state <= FETCH;
						when HALT =>
							leds <= (others => '0');
							display_number <= x"0000";
							current_state <= DECODE;
						when others => null;
					end case;
				when EXECUTE =>
					case op_code is 
							when LDA_MEM => regs(reg_addr) <= rom_data; current_state <= FETCH;
							when ADD | SUBS | MULT | DIV | ADD_IMM | SUB_IMM => regs(reg_addr) <= alu_res; current_state <= FETCH;
							when SLEEP =>
								if counter_delay < target_delay then
									counter_delay <= counter_delay + 1;
									current_state <= EXECUTE;
								else
									counter_delay <= 0;
									current_state <= FETCH;
								end if;
							when others => regs(reg_addr) <= data_to_load; current_state <= FETCH;
					end case;
					--current_state <= FETCH;
			end case;
		end if;
	end process;
	
	with current_state select
		rom_addr <= PC 			 when FETCH,
						addr_operand when others;
	
		
end architecture Behavioral;
